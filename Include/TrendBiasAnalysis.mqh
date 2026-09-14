//================================================================================
// Gold MTF Key-Level & Structure Breakout EA
// TrendBiasAnalysis.mqh - Multi-Timeframe Trend Direction Assessment
// Purpose: Analyze trend bias across Structure, Confirmation, and Entry timeframes
//================================================================================

#ifndef __TRENDBIASANALYSIS_MQH__
#define __TRENDBIASANALYSIS_MQH__

#include "Config.mqh"

//================================================================================
// CLASS: CTrendBiasAnalysis
// Purpose: Determines market bias and trend direction across multiple timeframes
//================================================================================

class CTrendBiasAnalysis
{
private:
   ENUM_TIMEFRAMES m_structureTF;
   ENUM_TIMEFRAMES m_confirmTF;
   ENUM_TIMEFRAMES m_entryTF;
   
   string m_symbol;
   double m_symbol_point;
   
   // Cached trend data
   ENUM_TREND_BIAS m_structureBias;
   ENUM_TREND_BIAS m_confirmBias;
   ENUM_TREND_BIAS m_entryBias;
   
   datetime m_lastStructureUpdate;
   datetime m_lastConfirmUpdate;
   datetime m_lastEntryUpdate;
   
   // Moving averages for trend confirmation
   static const int MA_FAST = 20;
   static const int MA_SLOW = 50;
   static const int MA_METHOD = MODE_EMA;

public:
   //---------------------------------------------------------------------
   // Constructor
   //---------------------------------------------------------------------
   CTrendBiasAnalysis(ENUM_TIMEFRAMES structureTF, ENUM_TIMEFRAMES confirmTF, ENUM_TIMEFRAMES entryTF)
   {
      m_structureTF = structureTF;
      m_confirmTF = confirmTF;
      m_entryTF = entryTF;
      
      m_symbol = Symbol();
      m_symbol_point = Point();
      
      m_structureBias = BIAS_NEUTRAL;
      m_confirmBias = BIAS_NEUTRAL;
      m_entryBias = BIAS_NEUTRAL;
      
      m_lastStructureUpdate = 0;
      m_lastConfirmUpdate = 0;
      m_lastEntryUpdate = 0;
   }
   
   //---------------------------------------------------------------------
   // Destructor
   //---------------------------------------------------------------------
   ~CTrendBiasAnalysis()
   {
   }
   
   //---------------------------------------------------------------------
   // Main Update Function
   // Call on every tick or when new bar arrives
   //---------------------------------------------------------------------
   void Update()
   {
      UpdateStructureBias();
      UpdateConfirmBias();
      UpdateEntryBias();
   }
   
   //---------------------------------------------------------------------
   // Update Structure Timeframe Bias (HTF - Daily/Weekly)
   // Uses: Higher timeframe candles + Moving averages + Support/Resistance
   //---------------------------------------------------------------------
   void UpdateStructureBias()
   {
      datetime currentTime = iTime(m_symbol, m_structureTF, 0);
      
      // Only update on new bar
      if(currentTime == m_lastStructureUpdate)
         return;
      
      m_lastStructureUpdate = currentTime;
      
      // Method 1: Price vs Moving Averages
      double fastMA = iMA(m_symbol, m_structureTF, MA_FAST, 0, MA_METHOD, PRICE_CLOSE, 1);
      double slowMA = iMA(m_symbol, m_structureTF, MA_SLOW, 0, MA_METHOD, PRICE_CLOSE, 1);
      double close1 = iClose(m_symbol, m_structureTF, 1);
      
      // Method 2: Candle body direction
      double open1 = iOpen(m_symbol, m_structureTF, 1);
      bool isBullishBody = close1 > open1;
      bool isBearishBody = close1 < open1;
      
      // Determine bias
      ENUM_TREND_BIAS maBias = BIAS_NEUTRAL;
      if(close1 > fastMA && fastMA > slowMA)
         maBias = BIAS_BULLISH;
      else if(close1 < fastMA && fastMA < slowMA)
         maBias = BIAS_BEARISH;
      
      // Combine methods with weighting
      m_structureBias = BIAS_NEUTRAL;
      
      if(maBias == BIAS_BULLISH && isBullishBody)
         m_structureBias = BIAS_BULLISH;
      else if(maBias == BIAS_BEARISH && isBearishBody)
         m_structureBias = BIAS_BEARISH;
      else if(maBias != BIAS_NEUTRAL)
         m_structureBias = maBias;  // MA bias without confirmation
   }
   
   //---------------------------------------------------------------------
   // Update Confirmation Timeframe Bias (H4)
   // Uses: H4 candles + Moving averages + Recent trend
   //---------------------------------------------------------------------
   void UpdateConfirmBias()
   {
      datetime currentTime = iTime(m_symbol, m_confirmTF, 0);
      
      // Only update on new bar
      if(currentTime == m_lastConfirmUpdate)
         return;
      
      m_lastConfirmUpdate = currentTime;
      
      // Method 1: Price vs Moving Averages
      double fastMA = iMA(m_symbol, m_confirmTF, MA_FAST, 0, MA_METHOD, PRICE_CLOSE, 1);
      double slowMA = iMA(m_symbol, m_confirmTF, MA_SLOW, 0, MA_METHOD, PRICE_CLOSE, 1);
      double close1 = iClose(m_symbol, m_confirmTF, 1);
      
      // Method 2: Recent candles trend
      double close2 = iClose(m_symbol, m_confirmTF, 2);
      double close3 = iClose(m_symbol, m_confirmTF, 3);
      
      bool isUptrend = close1 > close2 && close2 > close3;
      bool isDowntrend = close1 < close2 && close2 < close3;
      
      // Determine bias
      ENUM_TREND_BIAS maBias = BIAS_NEUTRAL;
      if(close1 > fastMA && fastMA > slowMA)
         maBias = BIAS_BULLISH;
      else if(close1 < fastMA && fastMA < slowMA)
         maBias = BIAS_BEARISH;
      
      m_confirmBias = BIAS_NEUTRAL;
      
      if(maBias == BIAS_BULLISH && isUptrend)
         m_confirmBias = BIAS_BULLISH;
      else if(maBias == BIAS_BEARISH && isDowntrend)
         m_confirmBias = BIAS_BEARISH;
      else if(maBias != BIAS_NEUTRAL)
         m_confirmBias = maBias;
   }
   
   //---------------------------------------------------------------------
   // Update Entry Timeframe Bias (H1/M15)
   // Uses: Entry TF candles + Swing patterns
   //---------------------------------------------------------------------
   void UpdateEntryBias()
   {
      datetime currentTime = iTime(m_symbol, m_entryTF, 0);
      
      // Only update on new bar
      if(currentTime == m_lastEntryUpdate)
         return;
      
      m_lastEntryUpdate = currentTime;
      
      // Method: Check for higher highs/lows (uptrend) or lower lows/highs (downtrend)
      double high1 = iHigh(m_symbol, m_entryTF, 1);
      double high2 = iHigh(m_symbol, m_entryTF, 2);
      double low1 = iLow(m_symbol, m_entryTF, 1);
      double low2 = iLow(m_symbol, m_entryTF, 2);
      double close1 = iClose(m_symbol, m_entryTF, 1);
      double open1 = iOpen(m_symbol, m_entryTF, 1);
      
      // Check for higher high + higher low
      bool isHigherHigh = high1 > high2;
      bool isHigherLow = low1 > low2;
      
      // Check for lower low + lower high
      bool isLowerLow = low1 < low2;
      bool isLowerHigh = high1 < high2;
      
      // Candle body confirmation
      bool isBullishBody = close1 > open1;
      bool isBearishBody = close1 < open1;
      
      m_entryBias = BIAS_NEUTRAL;
      
      if(isHigherHigh && isHigherLow && isBullishBody)
         m_entryBias = BIAS_BULLISH;
      else if(isLowerLow && isLowerHigh && isBearishBody)
         m_entryBias = BIAS_BEARISH;
      else if(isHigherHigh && isHigherLow)
         m_entryBias = BIAS_BULLISH;
      else if(isLowerLow && isLowerHigh)
         m_entryBias = BIAS_BEARISH;
   }
   
   //---------------------------------------------------------------------
   // GETTER: Overall Market Bias (Alignment of all timeframes)
   // Returns: BULLISH if all/most TFs aligned bullish, BEARISH if all/most aligned bearish
   //---------------------------------------------------------------------
   ENUM_TREND_BIAS GetOverallBias()
   {
      int bullishCount = 0;
      int bearishCount = 0;
      
      if(m_structureBias == BIAS_BULLISH) bullishCount++;
      else if(m_structureBias == BIAS_BEARISH) bearishCount++;
      
      if(m_confirmBias == BIAS_BULLISH) bullishCount++;
      else if(m_confirmBias == BIAS_BEARISH) bearishCount++;
      
      if(m_entryBias == BIAS_BULLISH) bullishCount++;
      else if(m_entryBias == BIAS_BEARISH) bearishCount++;
      
      if(bullishCount >= 2)
         return BIAS_BULLISH;
      if(bearishCount >= 2)
         return BIAS_BEARISH;
      
      return BIAS_NEUTRAL;
   }
   
   //---------------------------------------------------------------------
   // GETTER: Structure Timeframe Bias
   //---------------------------------------------------------------------
   ENUM_TREND_BIAS GetStructureBias()
   {
      return m_structureBias;
   }
   
   //---------------------------------------------------------------------
   // GETTER: Confirmation Timeframe Bias
   //---------------------------------------------------------------------
   ENUM_TREND_BIAS GetConfirmBias()
   {
      return m_confirmBias;
   }
   
   //---------------------------------------------------------------------
   // GETTER: Entry Timeframe Bias
   //---------------------------------------------------------------------
   ENUM_TREND_BIAS GetEntryBias()
   {
      return m_entryBias;
   }
   
   //---------------------------------------------------------------------
   // Check if all timeframes are aligned (bullish or bearish)
   //---------------------------------------------------------------------
   bool IsFullyAligned()
   {
      return (m_structureBias != BIAS_NEUTRAL && 
              m_structureBias == m_confirmBias && 
              m_confirmBias == m_entryBias);
   }
   
   //---------------------------------------------------------------------
   // Check if Structure and Confirmation TFs are aligned
   //---------------------------------------------------------------------
   bool IsHTFAligned()
   {
      return (m_structureBias != BIAS_NEUTRAL && 
              m_structureBias == m_confirmBias);
   }
   
   //---------------------------------------------------------------------
   // Get alignment strength (0-3, where 3 = fully aligned)
   //---------------------------------------------------------------------
   int GetAlignmentStrength()
   {
      int strength = 0;
      
      if(m_structureBias != BIAS_NEUTRAL)
         strength++;
      if(m_confirmBias != BIAS_NEUTRAL)
         strength++;
      if(m_entryBias != BIAS_NEUTRAL)
         strength++;
      
      // Bonus if all same direction
      if(m_structureBias == m_confirmBias && m_confirmBias == m_entryBias && 
         m_structureBias != BIAS_NEUTRAL)
         strength = 3;
      
      return strength;
   }
   
   //---------------------------------------------------------------------
   // Get Higher Timeframe Bias (for entry decisions)
   // Priority: Structure > Confirm > Entry
   //---------------------------------------------------------------------
   ENUM_TREND_BIAS GetHTFBias()
   {
      if(m_structureBias != BIAS_NEUTRAL)
         return m_structureBias;
      if(m_confirmBias != BIAS_NEUTRAL)
         return m_confirmBias;
      return m_entryBias;
   }
   
   //---------------------------------------------------------------------
   // Check if bias is stable (no rapid reversals)
   // Compare current bias with previous bar's bias
   //---------------------------------------------------------------------
   bool IsBiasStable(ENUM_TREND_BIAS currentBias, int barsBack = 3)
   {
      int consistentBars = 0;
      
      // This would need caching of previous biases - simplified version:
      return true;  // Placeholder for now
   }
   
   //---------------------------------------------------------------------
   // Get distance of price from key MA levels (in pips)
   //---------------------------------------------------------------------
   double GetDistanceFromMA(ENUM_TIMEFRAMES tf, double &fastMA, double &slowMA)
   {
      fastMA = iMA(m_symbol, tf, MA_FAST, 0, MA_METHOD, PRICE_CLOSE, 1);
      slowMA = iMA(m_symbol, tf, MA_SLOW, 0, MA_METHOD, PRICE_CLOSE, 1);
      
      double close = iClose(m_symbol, tf, 0);
      double avgMA = (fastMA + slowMA) / 2.0;
      
      return MathAbs(close - avgMA) / m_symbol_point;
   }
   
   //---------------------------------------------------------------------
   // Get trend strength indicator (RSI-based on recent closes)
   //---------------------------------------------------------------------
   double GetTrendStrength(ENUM_TIMEFRAMES tf)
   {
      double sum = 0;
      int count = 0;
      
      // Calculate momentum over last 5 bars
      for(int i = 1; i <= 5; i++)
      {
         double close = iClose(m_symbol, tf, i);
         double prev = iClose(m_symbol, tf, i + 1);
         sum += (close - prev);
         count++;
      }
      
      return sum / count / m_symbol_point;  // Return in pips
   }
};

//================================================================================
#endif // __TRENDBIASANALYSIS_MQH__
//================================================================================
