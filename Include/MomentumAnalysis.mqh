//================================================================================
// Gold MTF Key-Level & Structure Breakout EA
// MomentumAnalysis.mqh - Momentum Loss & CHOCH/BOS Detection
// Purpose: Detect shrinking bodies, pinbars, rejection patterns, and CHOCH breakouts
//================================================================================

#ifndef __MOMENTUMANALYSIS_MQH__
#define __MOMENTUMANALYSIS_MQH__

#include "Config.mqh"

//================================================================================
// CLASS: CMomentumAnalysis
// Purpose: Analyze momentum loss and CHOCH/BOS breakout patterns
//================================================================================

class CMomentumAnalysis
{
private:
   ENUM_TIMEFRAMES m_entryTF;
   string m_symbol;
   double m_symbol_point;
   
   // Cached momentum data
   STRUCT_MOMENTUM_DATA m_currentMomentum;
   STRUCT_MOMENTUM_DATA m_lastMomentum;
   
   // CHOCH/BOS tracking
   double m_lastHigherHigh;
   double m_lastLowerLow;
   double m_lastHigherLow;
   double m_lastLowerHigh;
   
   int m_lastHigherHighBar;
   int m_lastLowerLowBar;
   int m_lastHigherLowBar;
   int m_lastLowerHighBar;
   
   datetime m_lastUpdate;

public:
   //---------------------------------------------------------------------
   // Constructor
   //---------------------------------------------------------------------
   CMomentumAnalysis(ENUM_TIMEFRAMES entryTF)
   {
      m_entryTF = entryTF;
      m_symbol = Symbol();
      m_symbol_point = Point();
      
      // Initialize momentum data
      ZeroMemory(m_currentMomentum);
      ZeroMemory(m_lastMomentum);
      
      m_lastHigherHigh = 0;
      m_lastLowerLow = DBL_MAX;
      m_lastHigherLow = 0;
      m_lastLowerHigh = DBL_MAX;
      
      m_lastHigherHighBar = 0;
      m_lastLowerLowBar = 0;
      m_lastHigherLowBar = 0;
      m_lastLowerHighBar = 0;
      
      m_lastUpdate = 0;
   }
   
   //---------------------------------------------------------------------
   // Destructor
   //---------------------------------------------------------------------
   ~CMomentumAnalysis()
   {
   }
   
   //---------------------------------------------------------------------
   // Main Update Function
   // Call on every tick or when new bar arrives on Entry TF
   //---------------------------------------------------------------------
   void Update()
   {
      datetime currentTime = iTime(m_symbol, m_entryTF, 0);
      
      // Only update on new bar
      if(currentTime == m_lastUpdate)
         return;
      
      m_lastUpdate = currentTime;
      
      // Store previous momentum data
      m_lastMomentum = m_currentMomentum;
      
      // Calculate current candle momentum
      AnalyzeCurrentCandle();
      
      // Update CHOCH/BOS swing tracking
      UpdateSwingTracking();
   }
   
   //---------------------------------------------------------------------
   // Analyze Current Candle (bar 1 - last closed bar)
   // Calculate: body size, body %, pinbar status, rejection shadow
   //---------------------------------------------------------------------
   void AnalyzeCurrentCandle()
   {
      double open1 = iOpen(m_symbol, m_entryTF, 1);
      double close1 = iClose(m_symbol, m_entryTF, 1);
      double high1 = iHigh(m_symbol, m_entryTF, 1);
      double low1 = iLow(m_symbol, m_entryTF, 1);
      
      // Body size (in pips)
      m_currentMomentum.bodySize = MathAbs(close1 - open1) / m_symbol_point;
      
      // Range of candle
      double range = (high1 - low1) / m_symbol_point;
      
      // Body as percentage of range (0-1)
      if(range > 0)
         m_currentMomentum.bodyPercent = m_currentMomentum.bodySize / range;
      else
         m_currentMomentum.bodyPercent = 0;
      
      // Check for pinbar (small body, large wicks)
      m_currentMomentum.isPinbar = DetectPinbar(open1, close1, high1, low1);
      
      // Calculate rejection shadow (wick against trend)
      m_currentMomentum.rejectionShadow = CalculateRejectionShadow(open1, close1, high1, low1);
      
      // Check if this is a rejection candle
      m_currentMomentum.isRejection = m_currentMomentum.isPinbar || 
                                       (m_currentMomentum.rejectionShadow > m_currentMomentum.bodySize * 2);
      
      // Count consecutive shrinking bars
      m_currentMomentum.shrinkingBars = CountShrinkingBars();
   }
   
   //---------------------------------------------------------------------
   // Detect Pinbar Pattern
   // Pinbar: Small body with at least one wick > 2x body size
   //---------------------------------------------------------------------
   bool DetectPinbar(double open, double close, double high, double low)
   {
      double bodySize = MathAbs(close - open);
      double upperWick = high - MathMax(open, close);
      double lowerWick = MathMin(open, close) - low;
      
      // Pinbar criteria: small body + large wick
      double maxWick = MathMax(upperWick, lowerWick);
      
      if(bodySize == 0)
         return false;
      
      // If max wick is at least 2x the body, it's a pinbar
      return maxWick > bodySize * 2.0;
   }
   
   //---------------------------------------------------------------------
   // Calculate Rejection Shadow Size (in pips)
   // For bullish rejection: lower shadow when close is near high
   // For bearish rejection: upper shadow when close is near low
   //---------------------------------------------------------------------
   double CalculateRejectionShadow(double open, double close, double high, double low)
   {
      bool isCloseBullish = close > open;
      
      if(isCloseBullish)
      {
         // For bullish candles, rejection shadow is the lower wick
         double lowerWick = MathMin(open, close) - low;
         return lowerWick / m_symbol_point;
      }
      else
      {
         // For bearish candles, rejection shadow is the upper wick
         double upperWick = high - MathMax(open, close);
         return upperWick / m_symbol_point;
      }
   }
   
   //---------------------------------------------------------------------
   // Count Consecutive Candles with Shrinking Body Size
   // Returns: Number of consecutive bars with smaller body than previous
   //---------------------------------------------------------------------
   int CountShrinkingBars()
   {
      int shrinkingCount = 0;
      double prevBodySize = m_lastMomentum.bodySize;
      
      // Check last 5 bars for shrinking pattern
      for(int i = 1; i <= 5; i++)
      {
         double open = iOpen(m_symbol, m_entryTF, i);
         double close = iClose(m_symbol, m_entryTF, i);
         double currentBodySize = MathAbs(close - open) / m_symbol_point;
         
         if(currentBodySize < prevBodySize)
         {
            shrinkingCount++;
            prevBodySize = currentBodySize;
         }
         else
         {
            break;  // Break streak on first larger candle
         }
      }
      
      return shrinkingCount;
   }
   
   //---------------------------------------------------------------------
   // Update CHOCH/BOS Swing Tracking
   // Tracks: Higher Highs, Lower Lows, Higher Lows, Lower Highs
   // Used for CHOCH/BOS detection on entry TF
   //---------------------------------------------------------------------
   void UpdateSwingTracking()
   {
      double high1 = iHigh(m_symbol, m_entryTF, 1);
      double low1 = iLow(m_symbol, m_entryTF, 1);
      double high2 = iHigh(m_symbol, m_entryTF, 2);
      double low2 = iLow(m_symbol, m_entryTF, 2);
      
      // Update Higher Highs (for uptrend CHOCH)
      if(high1 > m_lastHigherHigh)
      {
         m_lastHigherHigh = high1;
         m_lastHigherHighBar = 1;
      }
      else
      {
         m_lastHigherHighBar++;
      }
      
      // Update Lower Lows (for downtrend CHOCH)
      if(low1 < m_lastLowerLow)
      {
         m_lastLowerLow = low1;
         m_lastLowerLowBar = 1;
      }
      else
      {
         m_lastLowerLowBar++;
      }
      
      // Update Higher Lows (bullish structure)
      if(low1 > m_lastHigherLow)
      {
         m_lastHigherLow = low1;
         m_lastHigherLowBar = 1;
      }
      else
      {
         m_lastHigherLowBar++;
      }
      
      // Update Lower Highs (bearish structure)
      if(high1 < m_lastLowerHigh)
      {
         m_lastLowerHigh = high1;
         m_lastLowerHighBar = 1;
      }
      else
      {
         m_lastLowerHighBar++;
      }
      
      // Initialize if first call
      if(m_lastHigherHigh == 0)
         m_lastHigherHigh = high1;
      if(m_lastLowerLow == DBL_MAX)
         m_lastLowerLow = low1;
      if(m_lastHigherLow == 0)
         m_lastHigherLow = low1;
      if(m_lastLowerHigh == DBL_MAX)
         m_lastLowerHigh = high1;
   }
   
   //---------------------------------------------------------------------
   // Detect CHOCH Bullish (Break of Structure - Higher Low Break)
   // Validates: Last close > Last Lower High (previous resistance)
   // Momentum: Body should be strong (>60% of range)
   //---------------------------------------------------------------------
   bool DetectCHOCHBullish()
   {
      double close1 = iClose(m_symbol, m_entryTF, 1);
      double high1 = iHigh(m_symbol, m_entryTF, 1);
      double low1 = iLow(m_symbol, m_entryTF, 1);
      double range1 = (high1 - low1) / m_symbol_point;
      
      // Requirements for bullish CHOCH:
      // 1. Close above previous lower high
      // 2. Close-based confirmation (not just wick)
      // 3. Strong body (at least 50% of range)
      
      bool aboveResistance = close1 > m_lastLowerHigh;
      bool strongBody = m_currentMomentum.bodyPercent >= 0.50;
      
      // Validate last lower high was formed recently (within 5 bars)
      bool isRecent = m_lastLowerHighBar <= 5;
      
      return aboveResistance && strongBody && isRecent && m_currentMomentum.bodySize > 0;
   }
   
   //---------------------------------------------------------------------
   // Detect CHOCH Bearish (Break of Structure - Lower High Break)
   // Validates: Last close < Last Higher Low (previous support)
   // Momentum: Body should be strong (>60% of range)
   //---------------------------------------------------------------------
   bool DetectCHOCHBearish()
   {
      double close1 = iClose(m_symbol, m_entryTF, 1);
      double high1 = iHigh(m_symbol, m_entryTF, 1);
      double low1 = iLow(m_symbol, m_entryTF, 1);
      double range1 = (high1 - low1) / m_symbol_point;
      
      // Requirements for bearish CHOCH:
      // 1. Close below previous higher low
      // 2. Close-based confirmation (not just wick)
      // 3. Strong body (at least 50% of range)
      
      bool belowSupport = close1 < m_lastHigherLow;
      bool strongBody = m_currentMomentum.bodyPercent >= 0.50;
      
      // Validate last higher low was formed recently (within 5 bars)
      bool isRecent = m_lastHigherLowBar <= 5;
      
      return belowSupport && strongBody && isRecent && m_currentMomentum.bodySize > 0;
   }
   
   //---------------------------------------------------------------------
   // Detect Loss of Momentum at Key Level
   // Signs: Shrinking bodies + Rejections/Pinbars
   //---------------------------------------------------------------------
   bool DetectMomentumLoss()
   {
      // Criteria for momentum loss:
      // 1. Consecutive shrinking bars (at least 2)
      // 2. OR small body with rejection shadow
      // 3. Last candle shows rejection pattern (pinbar)
      
      bool hasShrinkingPattern = m_currentMomentum.shrinkingBars >= 2;
      bool hasRejectionPattern = m_currentMomentum.isRejection && m_currentMomentum.rejectionShadow > 15;  // >15 pips shadow
      bool smallBody = m_currentMomentum.bodyPercent < 0.40;  // <40% of range
      
      return (hasShrinkingPattern || (hasRejectionPattern && smallBody));
   }
   
   //---------------------------------------------------------------------
   // Check if price is approaching a key level with momentum loss
   // Used for pre-entry validation near HTF support/resistance
   //---------------------------------------------------------------------
   bool IsMomentumLossNearLevel(double keyLevelPrice, double tolerancePips = 30)
   {
      double currentPrice = iClose(m_symbol, m_entryTF, 0);
      double distToLevel = MathAbs(currentPrice - keyLevelPrice) / m_symbol_point;
      
      // Within tolerance zone AND showing momentum loss
      return distToLevel <= tolerancePips && DetectMomentumLoss();
   }
   
   //---------------------------------------------------------------------
   // GETTER: Current Momentum Data
   //---------------------------------------------------------------------
   STRUCT_MOMENTUM_DATA GetCurrentMomentum()
   {
      return m_currentMomentum;
   }
   
   //---------------------------------------------------------------------
   // GETTER: Last Higher High Price
   //---------------------------------------------------------------------
   double GetLastHigherHigh()
   {
      return m_lastHigherHigh;
   }
   
   //---------------------------------------------------------------------
   // GETTER: Last Lower Low Price
   //---------------------------------------------------------------------
   double GetLastLowerLow()
   {
      return m_lastLowerLow;
   }
   
   //---------------------------------------------------------------------
   // GETTER: Last Higher Low (bullish support)
   //---------------------------------------------------------------------
   double GetLastHigherLow()
   {
      return m_lastHigherLow;
   }
   
   //---------------------------------------------------------------------
   // GETTER: Last Lower High (bearish resistance)
   //---------------------------------------------------------------------
   double GetLastLowerHigh()
   {
      return m_lastLowerHigh;
   }
   
   //---------------------------------------------------------------------
   // GETTER: Bars since Higher High
   //---------------------------------------------------------------------
   int GetBarsSinceHigherHigh()
   {
      return m_lastHigherHighBar;
   }
   
   //---------------------------------------------------------------------
   // GETTER: Bars since Lower Low
   //---------------------------------------------------------------------
   int GetBarsSinceLowerLow()
   {
      return m_lastLowerLowBar;
   }
   
   //---------------------------------------------------------------------
   // Check for Bullish Momentum (Increasing Highs and Lows)
   // Used to validate bullish CHOCH quality
   //---------------------------------------------------------------------
   bool IsBullishMomentum()
   {
      // Bullish momentum = Higher Highs + Higher Lows
      double high2 = iHigh(m_symbol, m_entryTF, 2);
      double low2 = iLow(m_symbol, m_entryTF, 2);
      
      bool higherHigh = m_lastHigherHigh > high2;
      bool higherLow = m_lastHigherLow > low2;
      bool bullishClose = iClose(m_symbol, m_entryTF, 1) > iOpen(m_symbol, m_entryTF, 1);
      
      return higherHigh && higherLow && bullishClose;
   }
   
   //---------------------------------------------------------------------
   // Check for Bearish Momentum (Decreasing Highs and Lows)
   // Used to validate bearish CHOCH quality
   //---------------------------------------------------------------------
   bool IsBearishMomentum()
   {
      // Bearish momentum = Lower Highs + Lower Lows
      double high2 = iHigh(m_symbol, m_entryTF, 2);
      double low2 = iLow(m_symbol, m_entryTF, 2);
      
      bool lowerHigh = m_lastLowerHigh < high2;
      bool lowerLow = m_lastLowerLow < low2;
      bool bearishClose = iClose(m_symbol, m_entryTF, 1) < iOpen(m_symbol, m_entryTF, 1);
      
      return lowerHigh && lowerLow && bearishClose;
   }
   
   //---------------------------------------------------------------------
   // Get momentum quality score (0-10)
   // Higher = stronger momentum confirmation
   //---------------------------------------------------------------------
   int GetMomentumScore()
   {
      int score = 0;
      
      // Strong body adds points
      if(m_currentMomentum.bodyPercent > 0.70)
         score += 3;
      else if(m_currentMomentum.bodyPercent > 0.50)
         score += 2;
      else if(m_currentMomentum.bodyPercent > 0.30)
         score += 1;
      
      // Bullish/Bearish candle
      if(iClose(m_symbol, m_entryTF, 1) > iOpen(m_symbol, m_entryTF, 1))
         score += 2;  // Bullish candle
      else if(iClose(m_symbol, m_entryTF, 1) < iOpen(m_symbol, m_entryTF, 1))
         score += 1;  // Bearish candle at least confirms direction
      
      // No rejection pattern (clean break)
      if(!m_currentMomentum.isRejection)
         score += 2;
      
      // Recent swing structure
      if(GetBarsSinceHigherHigh() <= 3 || GetBarsSinceLowerLow() <= 3)
         score += 2;
      
      return MathMin(score, 10);
   }
   
   //---------------------------------------------------------------------
   // Reset momentum tracking
   //---------------------------------------------------------------------
   void Reset()
   {
      ZeroMemory(m_currentMomentum);
      ZeroMemory(m_lastMomentum);
      m_lastHigherHigh = 0;
      m_lastLowerLow = DBL_MAX;
      m_lastHigherLow = 0;
      m_lastLowerHigh = DBL_MAX;
      m_lastUpdate = 0;
   }
};

//================================================================================
#endif // __MOMENTUMANALYSIS_MQH__
//================================================================================
