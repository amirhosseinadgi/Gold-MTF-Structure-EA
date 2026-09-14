//================================================================================
// Gold MTF Key-Level & Structure Breakout EA
// PatternRecognition.mqh - M-Top, W-Bottom, and Head & Shoulders Detection
// Purpose: Identify chart patterns based on broken necklines and key levels
//================================================================================

#ifndef __PATTERNRECOGNITION_MQH__
#define __PATTERNRECOGNITION_MQH__

#include "Config.mqh"
#include "KeyLevelDetection.mqh"

//================================================================================
// CLASS: CPatternRecognition
// Purpose: Detects M-top, W-bottom, and Head & Shoulders patterns
//================================================================================

class CPatternRecognition
{
private:
   ENUM_TIMEFRAMES m_timeframe;
   string m_symbol;
   double m_symbol_point;
   
   // Pattern cache
   ENUM_PATTERN_TYPE m_lastPattern;
   double m_necklinePrice;
   bool m_necklineBroken;
   int m_patternBarIndex;
   datetime m_patternTime;

public:
   //---------------------------------------------------------------------
   // Constructor
   //---------------------------------------------------------------------
   CPatternRecognition(ENUM_TIMEFRAMES timeframe)
   {
      m_timeframe = timeframe;
      m_symbol = Symbol();
      m_symbol_point = Point();
      
      m_lastPattern = PATTERN_NONE;
      m_necklinePrice = 0;
      m_necklineBroken = false;
      m_patternBarIndex = 0;
      m_patternTime = 0;
   }
   
   //---------------------------------------------------------------------
   // Destructor
   //---------------------------------------------------------------------
   ~CPatternRecognition()
   {
   }
   
   //---------------------------------------------------------------------
   // Main Update & Pattern Detection
   // Should be called after key levels are identified
   //---------------------------------------------------------------------
   ENUM_PATTERN_TYPE DetectPatterns()
   {
      ENUM_PATTERN_TYPE pattern = PATTERN_NONE;
      
      // Try to detect each pattern in order of importance
      if(DetectMTop(m_necklinePrice))
      {
         pattern = PATTERN_M_TOP;
      }
      else if(DetectWBottom(m_necklinePrice))
      {
         pattern = PATTERN_W_BOTTOM;
      }
      else if(DetectHeadAndShoulders(m_necklinePrice))
      {
         pattern = PATTERN_HEAD_SHOULDERS;
      }
      
      m_lastPattern = pattern;
      return pattern;
   }
   
   //---------------------------------------------------------------------
   // Detect M-Top Pattern
   // Structure: Low -> High (left shoulder) -> Low (neckline) -> High (head) -> Low -> High (right shoulder) -> BREAK BELOW
   // Validation: Neckline must be broken on close to confirm pattern
   //---------------------------------------------------------------------
   bool DetectMTop(double &necklinePrice)
   {
      necklinePrice = 0;
      
      // Look back 20 bars for pattern formation
      int bars = iBars(m_symbol, m_timeframe);
      if(bars < 20)
         return false;
      
      // Find recent peaks and troughs
      double peak1 = -1, trough1 = -1, peak2 = -1, trough2 = -1;
      int peakBar1 = -1, troughBar1 = -1, peakBar2 = -1, troughBar2 = -1;
      
      // Scan for 2 peaks and 1-2 troughs in recent bars
      int peakCount = 0;
      int troughCount = 0;
      
      for(int i = 5; i < 20; i++)
      {
         double high = iHigh(m_symbol, m_timeframe, i);
         double low = iLow(m_symbol, m_timeframe, i);
         double prevHigh = iHigh(m_symbol, m_timeframe, i + 1);
         double prevLow = iLow(m_symbol, m_timeframe, i + 1);
         double nextHigh = iHigh(m_symbol, m_timeframe, i - 1);
         double nextLow = iLow(m_symbol, m_timeframe, i - 1);
         
         // Local high (peak)
         if(high > prevHigh && high > nextHigh && high > low * 1.002)  // Peak should be at least 0.2% above current low
         {
            if(peakCount == 0)
            {
               peak1 = high;
               peakBar1 = i;
               peakCount++;
            }
            else if(peakCount == 1)
            {
               peak2 = high;
               peakBar2 = i;
               peakCount++;
               break;  // Got 2 peaks
            }
         }
         
         // Local low (trough)
         if(low < prevLow && low < nextLow)
         {
            if(troughCount == 0)
            {
               trough1 = low;
               troughBar1 = i;
               troughCount++;
            }
            else if(troughCount == 1)
            {
               trough2 = low;
               troughBar2 = i;
               troughCount++;
            }
         }
      }
      
      // Validate M-Top structure:
      // - 2 peaks at similar height
      // - Neckline is the trough between them (lower than both peaks)
      // - Current price should be approaching or breaking below neckline
      
      if(peakCount >= 2 && troughCount >= 1)
      {
         // Neckline should be the most recent low
         necklinePrice = trough1;
         
         // Peaks should be at similar height (within 1%)
         double peakDiff = MathAbs(peak1 - peak2) / peak1;
         if(peakDiff > 0.01)  // More than 1% difference
            return false;
         
         // Check if peaks are significantly above neckline
         if(peak1 < necklinePrice * 1.005)  // Less than 0.5% above neckline
            return false;
         
         // Check if current price is near neckline (for pattern confirmation)
         double currentPrice = iClose(m_symbol, m_timeframe, 0);
         double distToNeckline = MathAbs(currentPrice - necklinePrice) / m_symbol_point;
         
         if(distToNeckline > 100)  // More than 100 pips away
            return false;
         
         m_necklinePrice = necklinePrice;
         m_patternBarIndex = 0;
         m_patternTime = iTime(m_symbol, m_timeframe, 0);
         return true;
      }
      
      return false;
   }
   
   //---------------------------------------------------------------------
   // Detect W-Bottom Pattern
   // Structure: High (left shoulder) -> Low -> High (neckline) -> Low (valley) -> High (right shoulder) -> BREAK ABOVE
   // Validation: Neckline must be broken on close to confirm pattern
   //---------------------------------------------------------------------
   bool DetectWBottom(double &necklinePrice)
   {
      necklinePrice = 0;
      
      // Look back 20 bars for pattern formation
      int bars = iBars(m_symbol, m_timeframe);
      if(bars < 20)
         return false;
      
      // Find recent troughs and peaks
      double trough1 = -1, peak1 = -1, trough2 = -1, peak2 = -1;
      int troughBar1 = -1, peakBar1 = -1, troughBar2 = -1, peakBar2 = -1;
      
      int troughCount = 0;
      int peakCount = 0;
      
      for(int i = 5; i < 20; i++)
      {
         double high = iHigh(m_symbol, m_timeframe, i);
         double low = iLow(m_symbol, m_timeframe, i);
         double prevHigh = iHigh(m_symbol, m_timeframe, i + 1);
         double prevLow = iLow(m_symbol, m_timeframe, i + 1);
         double nextHigh = iHigh(m_symbol, m_timeframe, i - 1);
         double nextLow = iLow(m_symbol, m_timeframe, i - 1);
         
         // Local low (trough)
         if(low < prevLow && low < nextLow && low < high * 0.998)
         {
            if(troughCount == 0)
            {
               trough1 = low;
               troughBar1 = i;
               troughCount++;
            }
            else if(troughCount == 1)
            {
               trough2 = low;
               troughBar2 = i;
               troughCount++;
               break;  // Got 2 troughs
            }
         }
         
         // Local high (peak)
         if(high > prevHigh && high > nextHigh)
         {
            if(peakCount == 0)
            {
               peak1 = high;
               peakBar1 = i;
               peakCount++;
            }
            else if(peakCount == 1)
            {
               peak2 = high;
               peakBar2 = i;
               peakCount++;
            }
         }
      }
      
      // Validate W-Bottom structure:
      // - 2 troughs at similar depth
      // - Neckline is the peak between them (higher than both troughs)
      // - Current price should be approaching or breaking above neckline
      
      if(troughCount >= 2 && peakCount >= 1)
      {
         // Neckline should be the most recent peak
         necklinePrice = peak1;
         
         // Troughs should be at similar depth (within 1%)
         double troughDiff = MathAbs(trough1 - trough2) / trough1;
         if(troughDiff > 0.01)  // More than 1% difference
            return false;
         
         // Check if troughs are significantly below neckline
         if(trough1 > necklinePrice * 0.995)  // Less than 0.5% below neckline
            return false;
         
         // Check if current price is near neckline (for pattern confirmation)
         double currentPrice = iClose(m_symbol, m_timeframe, 0);
         double distToNeckline = MathAbs(currentPrice - necklinePrice) / m_symbol_point;
         
         if(distToNeckline > 100)  // More than 100 pips away
            return false;
         
         m_necklinePrice = necklinePrice;
         m_patternBarIndex = 0;
         m_patternTime = iTime(m_symbol, m_timeframe, 0);
         return true;
      }
      
      return false;
   }
   
   //---------------------------------------------------------------------
   // Detect Head & Shoulders Pattern
   // Structure: High (left shoulder) -> Low -> High (head, highest) -> Low (neckline) -> High (right shoulder, lower) -> BREAK BELOW
   // Validation: Right shoulder should be lower than left shoulder; neckline breaks down
   //---------------------------------------------------------------------
   bool DetectHeadAndShoulders(double &necklinePrice)
   {
      necklinePrice = 0;
      
      // Look back 25 bars for pattern formation
      int bars = iBars(m_symbol, m_timeframe);
      if(bars < 25)
         return false;
      
      // Find pattern components: left shoulder, head, right shoulder, and neckline
      double leftShoulder = -1, head = -1, rightShoulder = -1;
      double neckline1 = -1, neckline2 = -1;
      int headBar = -1;
      
      // Simplified detection: find 3 peaks where middle is highest
      int peakCount = 0;
      double peaks[10];
      int peakBars[10];
      int peakIdx = 0;
      
      for(int i = 5; i < 25; i++)
      {
         double high = iHigh(m_symbol, m_timeframe, i);
         double prevHigh = iHigh(m_symbol, m_timeframe, i + 1);
         double nextHigh = iHigh(m_symbol, m_timeframe, i - 1);
         
         if(high > prevHigh && high > nextHigh && peakIdx < 10)
         {
            peaks[peakIdx] = high;
            peakBars[peakIdx] = i;
            peakIdx++;
         }
      }
      
      // Need at least 3 peaks for H&S pattern
      if(peakIdx < 3)
         return false;
      
      // Check if middle peak is highest
      if(peaks[1] <= peaks[0] || peaks[1] <= peaks[2])
         return false;
      
      // Right shoulder should be significantly lower than left shoulder
      if(peaks[2] >= peaks[0] * 0.98)  // Right shoulder not at least 2% lower
         return false;
      
      leftShoulder = peaks[0];
      head = peaks[1];
      rightShoulder = peaks[2];
      
      // Find neckline (average of the two lows between shoulders and head)
      // This is simplified - in reality would find the exact low points
      necklinePrice = (leftShoulder + rightShoulder) / 2.0 * 0.97;  // Neckline roughly 3% below average shoulders
      
      // Validate pattern is complete
      double currentPrice = iClose(m_symbol, m_timeframe, 0);
      double distToNeckline = MathAbs(currentPrice - necklinePrice) / m_symbol_point;
      
      if(distToNeckline > 150)  // More than 150 pips away
         return false;
      
      m_necklinePrice = necklinePrice;
      m_patternBarIndex = 0;
      m_patternTime = iTime(m_symbol, m_timeframe, 0);
      return true;
   }
   
   //---------------------------------------------------------------------
   // GETTER: Last detected pattern type
   //---------------------------------------------------------------------
   ENUM_PATTERN_TYPE GetLastPattern()
   {
      return m_lastPattern;
   }
   
   //---------------------------------------------------------------------
   // GETTER: Neckline price of current pattern
   //---------------------------------------------------------------------
   double GetNecklinePrice()
   {
      return m_necklinePrice;
   }
   
   //---------------------------------------------------------------------
   // Check if neckline has been broken (close-based confirmation)
   // For M-Top: break below neckline
   // For W-Bottom: break above neckline
   // For H&S: break below neckline
   //---------------------------------------------------------------------
   bool IsNecklineBroken()
   {
      if(m_necklinePrice == 0)
         return false;
      
      double currentClose = iClose(m_symbol, m_timeframe, 0);
      double prevClose = iClose(m_symbol, m_timeframe, 1);
      
      if(m_lastPattern == PATTERN_W_BOTTOM)
      {
         // Bullish: price should close above neckline
         return currentClose > m_necklinePrice && prevClose <= m_necklinePrice;
      }
      else if(m_lastPattern == PATTERN_M_TOP || m_lastPattern == PATTERN_HEAD_SHOULDERS)
      {
         // Bearish: price should close below neckline
         return currentClose < m_necklinePrice && prevClose >= m_necklinePrice;
      }
      
      return false;
   }
   
   //---------------------------------------------------------------------
   // Get pattern formation time
   //---------------------------------------------------------------------
   datetime GetPatternTime()
   {
      return m_patternTime;
   }
   
   //---------------------------------------------------------------------
   // Get pattern bar index (relative to current bar)
   //---------------------------------------------------------------------
   int GetPatternBarIndex()
   {
      return m_patternBarIndex;
   }
   
   //---------------------------------------------------------------------
   // Calculate profit target based on pattern
   // M-Top: Target = Neckline - (Head - Neckline)
   // W-Bottom: Target = Neckline + (Neckline - Valley)
   //---------------------------------------------------------------------
   double CalculatePatternTarget(double headPrice)
   {
      if(m_necklinePrice == 0)
         return 0;
      
      double moveSize = MathAbs(headPrice - m_necklinePrice);
      
      if(m_lastPattern == PATTERN_M_TOP || m_lastPattern == PATTERN_HEAD_SHOULDERS)
      {
         // Bearish: target is below neckline
         return m_necklinePrice - moveSize;
      }
      else if(m_lastPattern == PATTERN_W_BOTTOM)
      {
         // Bullish: target is above neckline
         return m_necklinePrice + moveSize;
      }
      
      return 0;
   }
   
   //---------------------------------------------------------------------
   // Reset pattern detection (when price breaks pattern or pattern invalidates)
   //---------------------------------------------------------------------
   void Reset()
   {
      m_lastPattern = PATTERN_NONE;
      m_necklinePrice = 0;
      m_necklineBroken = false;
      m_patternBarIndex = 0;
      m_patternTime = 0;
   }
   
   //---------------------------------------------------------------------
   // Invalidate pattern if price moves too far from expected breakout zone
   //---------------------------------------------------------------------
   bool IsPatternInvalid()
   {
      if(m_necklinePrice == 0)
         return true;
      
      double currentPrice = iClose(m_symbol, m_timeframe, 0);
      
      if(m_lastPattern == PATTERN_M_TOP || m_lastPattern == PATTERN_HEAD_SHOULDERS)
      {
         // Pattern invalid if price goes above neckline + 2%
         return currentPrice > m_necklinePrice * 1.02;
      }
      else if(m_lastPattern == PATTERN_W_BOTTOM)
      {
         // Pattern invalid if price goes below neckline - 2%
         return currentPrice < m_necklinePrice * 0.98;
      }
      
      return false;
   }
};

//================================================================================
#endif // __PATTERNRECOGNITION_MQH__
//================================================================================
