//================================================================================
// Gold MTF Key-Level & Structure Breakout EA
// KeyLevelDetection.mqh - Swing & Key Level Detection Module
// Purpose: Identify swing highs/lows, detect patterns, and track key levels
//================================================================================

#ifndef __KEYLEVELDETECTION_MQH__
#define __KEYLEVELDETECTION_MQH__

#include "Config.mqh"

//================================================================================
// CLASS: CKeyLevelDetection
// Purpose: Detects swing points and key levels across timeframes
//================================================================================

class CKeyLevelDetection
{
private:
   ENUM_TIMEFRAMES m_timeframe;
   int m_lookback;
   int m_minDistance;
   double m_symbol_point;
   double m_tick_size;
   string m_symbol;
   
   // Cached swing data
   STRUCT_SWING_POINT m_swingHighs[];
   STRUCT_SWING_POINT m_swingLows[];
   int m_swingHighCount;
   int m_swingLowCount;
   
   // Key levels cache
   STRUCT_KEY_LEVEL m_keyLevels[];
   int m_keyLevelCount;
   
   datetime m_lastUpdateTime;

public:
   //---------------------------------------------------------------------
   // Constructor
   //---------------------------------------------------------------------
   CKeyLevelDetection(ENUM_TIMEFRAMES timeframe, int lookback, int minDistance)
   {
      m_timeframe = timeframe;
      m_lookback = lookback;
      m_minDistance = minDistance;
      m_symbol = Symbol();
      m_symbol_point = Point();
      m_tick_size = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
      
      m_swingHighCount = 0;
      m_swingLowCount = 0;
      m_keyLevelCount = 0;
      m_lastUpdateTime = 0;
      
      ArrayResize(m_swingHighs, 100);
      ArrayResize(m_swingLows, 100);
      ArrayResize(m_keyLevels, 50);
   }
   
   //---------------------------------------------------------------------
   // Destructor
   //---------------------------------------------------------------------
   ~CKeyLevelDetection()
   {
      ArrayFree(m_swingHighs);
      ArrayFree(m_swingLows);
      ArrayFree(m_keyLevels);
   }
   
   //---------------------------------------------------------------------
   // Main Update Function
   // Call this on every tick or when new bar arrives
   //---------------------------------------------------------------------
   void Update()
   {
      datetime currentTime = iTime(m_symbol, m_timeframe, 0);
      
      // Only update if a new bar has formed
      if(currentTime == m_lastUpdateTime)
         return;
      
      m_lastUpdateTime = currentTime;
      
      // Detect swings
      DetectSwings();
      
      // Build key levels from swings
      BuildKeyLevels();
   }
   
   //---------------------------------------------------------------------
   // Detect Swing Highs and Lows
   // Uses: 5 bars left + current + 5 bars right lookback
   //---------------------------------------------------------------------
   void DetectSwings()
   {
      int bars = iBars(m_symbol, m_timeframe);
      m_swingHighCount = 0;
      m_swingLowCount = 0;
      
      // Start from bar (m_lookback + 1) to avoid lookback edge
      // End at bar 1 (bar 0 is current, may be incomplete)
      for(int i = m_lookback + 1; i < bars - 1; i++)
      {
         if(IsSwingHigh(i))
         {
            AddSwingHigh(i);
         }
         
         if(IsSwingLow(i))
         {
            AddSwingLow(i);
         }
      }
   }
   
   //---------------------------------------------------------------------
   // Check if bar [i] is a Swing High
   // Condition: High[i] > High[i-lookback...i-1] AND High[i] > High[i+1...i+lookback]
   //---------------------------------------------------------------------
   bool IsSwingHigh(int barIndex)
   {
      double highPrice = iHigh(m_symbol, m_timeframe, barIndex);
      
      // Check bars to the left
      for(int i = 1; i <= m_lookback; i++)
      {
         if(iHigh(m_symbol, m_timeframe, barIndex + i) >= highPrice)
            return false;
      }
      
      // Check bars to the right
      for(int i = 1; i <= m_lookback; i++)
      {
         if(iHigh(m_symbol, m_timeframe, barIndex - i) >= highPrice)
            return false;
      }
      
      return true;
   }
   
   //---------------------------------------------------------------------
   // Check if bar [i] is a Swing Low
   // Condition: Low[i] < Low[i-lookback...i-1] AND Low[i] < Low[i+1...i+lookback]
   //---------------------------------------------------------------------
   bool IsSwingLow(int barIndex)
   {
      double lowPrice = iLow(m_symbol, m_timeframe, barIndex);
      
      // Check bars to the left
      for(int i = 1; i <= m_lookback; i++)
      {
         if(iLow(m_symbol, m_timeframe, barIndex + i) <= lowPrice)
            return false;
      }
      
      // Check bars to the right
      for(int i = 1; i <= m_lookback; i++)
      {
         if(iLow(m_symbol, m_timeframe, barIndex - i) <= lowPrice)
            return false;
      }
      
      return true;
   }
   
   //---------------------------------------------------------------------
   // Add Swing High to array
   //---------------------------------------------------------------------
   void AddSwingHigh(int barIndex)
   {
      if(m_swingHighCount >= ArraySize(m_swingHighs))
      {
         ArrayResize(m_swingHighs, m_swingHighCount + 50);
      }
      
      STRUCT_SWING_POINT swing;
      swing.price = iHigh(m_symbol, m_timeframe, barIndex);
      swing.barIndex = barIndex;
      swing.isHigh = true;
      swing.timeStamp = iTime(m_symbol, m_timeframe, barIndex);
      swing.strength = CalculateSwingStrength(barIndex, true);
      
      m_swingHighs[m_swingHighCount] = swing;
      m_swingHighCount++;
   }
   
   //---------------------------------------------------------------------
   // Add Swing Low to array
   //---------------------------------------------------------------------
   void AddSwingLow(int barIndex)
   {
      if(m_swingLowCount >= ArraySize(m_swingLows))
      {
         ArrayResize(m_swingLows, m_swingLowCount + 50);
      }
      
      STRUCT_SWING_POINT swing;
      swing.price = iLow(m_symbol, m_timeframe, barIndex);
      swing.barIndex = barIndex;
      swing.isHigh = false;
      swing.timeStamp = iTime(m_symbol, m_timeframe, barIndex);
      swing.strength = CalculateSwingStrength(barIndex, false);
      
      m_swingLows[m_swingLowCount] = swing;
      m_swingLowCount++;
   }
   
   //---------------------------------------------------------------------
   // Calculate Swing Strength (1-5 scale)
   // Stronger if surrounded by bigger differences
   //---------------------------------------------------------------------
   int CalculateSwingStrength(int barIndex, bool isHigh)
   {
      double swingPrice = isHigh ? iHigh(m_symbol, m_timeframe, barIndex) : 
                                    iLow(m_symbol, m_timeframe, barIndex);
      double totalDiff = 0;
      
      for(int i = 1; i <= m_lookback; i++)
      {
         if(isHigh)
         {
            totalDiff += (iHigh(m_symbol, m_timeframe, barIndex + i) - swingPrice);
            totalDiff += (iHigh(m_symbol, m_timeframe, barIndex - i) - swingPrice);
         }
         else
         {
            totalDiff += (swingPrice - iLow(m_symbol, m_timeframe, barIndex + i));
            totalDiff += (swingPrice - iLow(m_symbol, m_timeframe, barIndex - i));
         }
      }
      
      double avgDiff = MathAbs(totalDiff) / (2.0 * m_lookback);
      double pointsToUSD = PointsToUSD(avgDiff / m_symbol_point);
      
      if(pointsToUSD > 100) return 5;
      if(pointsToUSD > 75) return 4;
      if(pointsToUSD > 50) return 3;
      if(pointsToUSD > 25) return 2;
      return 1;
   }
   
   //---------------------------------------------------------------------
   // Build Key Levels from Swings
   // Consolidate swings within minimum distance and create key levels
   //---------------------------------------------------------------------
   void BuildKeyLevels()
   {
      m_keyLevelCount = 0;
      
      // Merge swing highs (supply levels)
      MergeLevels(m_swingHighs, m_swingHighCount, BIAS_BEARISH);
      
      // Merge swing lows (demand levels)
      MergeLevels(m_swingLows, m_swingLowCount, BIAS_BULLISH);
      
      // Sort key levels by price (ascending)
      SortKeyLevels();
   }
   
   //---------------------------------------------------------------------
   // Merge nearby swings into consolidated key levels
   //---------------------------------------------------------------------
   void MergeLevels(STRUCT_SWING_POINT &swings[], int swingCount, ENUM_TREND_BIAS bias)
   {
      if(swingCount == 0)
         return;
      
      // Start with the first (or most recent) swing
      for(int i = 0; i < swingCount; i++)
      {
         double swingPrice = swings[i].price;
         bool shouldAdd = true;
         
         // Check if this level is too close to an existing key level
         for(int j = 0; j < m_keyLevelCount; j++)
         {
            double distance = MathAbs(m_keyLevels[j].price - swingPrice);
            double distancePips = distance / m_symbol_point;
            
            if(distancePips < m_minDistance)
            {
               shouldAdd = false;
               // Keep the stronger swing
               if(swings[i].strength > m_keyLevels[j].pattern)
               {
                  m_keyLevels[j].price = swingPrice;
                  m_keyLevels[j].timeframeShift = swings[i].barIndex;
               }
               break;
            }
         }
         
         if(shouldAdd && m_keyLevelCount < ArraySize(m_keyLevels))
         {
            STRUCT_KEY_LEVEL keyLevel;
            keyLevel.price = swingPrice;
            keyLevel.bias = bias;
            keyLevel.timeframeShift = swings[i].barIndex;
            keyLevel.pattern = PATTERN_NONE;  // Will be updated by pattern detection
            keyLevel.isTested = false;
            keyLevel.isValid = true;
            keyLevel.timeCreated = swings[i].timeStamp;
            
            m_keyLevels[m_keyLevelCount] = keyLevel;
            m_keyLevelCount++;
         }
      }
   }
   
   //---------------------------------------------------------------------
   // Sort Key Levels by Price (Ascending)
   //---------------------------------------------------------------------
   void SortKeyLevels()
   {
      for(int i = 0; i < m_keyLevelCount - 1; i++)
      {
         for(int j = i + 1; j < m_keyLevelCount; j++)
         {
            if(m_keyLevels[j].price < m_keyLevels[i].price)
            {
               STRUCT_KEY_LEVEL temp = m_keyLevels[i];
               m_keyLevels[i] = m_keyLevels[j];
               m_keyLevels[j] = temp;
            }
         }
      }
   }
   
   //---------------------------------------------------------------------
   // GETTER: Latest Key Level Above Current Price (Supply)
   //---------------------------------------------------------------------
   bool GetSupplyLevel(double &outPrice)
   {
      double currentPrice = iClose(m_symbol, m_timeframe, 0);
      
      for(int i = 0; i < m_keyLevelCount; i++)
      {
         if(m_keyLevels[i].bias == BIAS_BEARISH && m_keyLevels[i].price > currentPrice)
         {
            outPrice = m_keyLevels[i].price;
            return true;
         }
      }
      return false;
   }
   
   //---------------------------------------------------------------------
   // GETTER: Latest Key Level Below Current Price (Demand)
   //---------------------------------------------------------------------
   bool GetDemandLevel(double &outPrice)
   {
      double currentPrice = iClose(m_symbol, m_timeframe, 0);
      
      // Find the highest demand level below price
      for(int i = m_keyLevelCount - 1; i >= 0; i--)
      {
         if(m_keyLevels[i].bias == BIAS_BULLISH && m_keyLevels[i].price < currentPrice)
         {
            outPrice = m_keyLevels[i].price;
            return true;
         }
      }
      return false;
   }
   
   //---------------------------------------------------------------------
   // GETTER: Distance to Nearest Key Level (in pips)
   //---------------------------------------------------------------------
   double GetDistanceToNearestLevel()
   {
      double currentPrice = iClose(m_symbol, m_timeframe, 0);
      double minDist = DBL_MAX;
      
      for(int i = 0; i < m_keyLevelCount; i++)
      {
         double dist = MathAbs(currentPrice - m_keyLevels[i].price) / m_symbol_point;
         if(dist < minDist)
            minDist = dist;
      }
      
      return (minDist == DBL_MAX) ? -1 : minDist;
   }
   
   //---------------------------------------------------------------------
   // GETTER: Get All Key Levels
   //---------------------------------------------------------------------
   int GetKeyLevels(STRUCT_KEY_LEVEL &outLevels[])
   {
      if(m_keyLevelCount > 0)
      {
         ArrayResize(outLevels, m_keyLevelCount);
         for(int i = 0; i < m_keyLevelCount; i++)
         {
            outLevels[i] = m_keyLevels[i];
         }
      }
      return m_keyLevelCount;
   }
   
   //---------------------------------------------------------------------
   // GETTER: Last Swing High (Current Trend Context)
   //---------------------------------------------------------------------
   bool GetLastSwingHigh(double &outPrice)
   {
      if(m_swingHighCount > 0)
      {
         outPrice = m_swingHighs[0].price;
         return true;
      }
      return false;
   }
   
   //---------------------------------------------------------------------
   // GETTER: Last Swing Low (Current Trend Context)
   //---------------------------------------------------------------------
   bool GetLastSwingLow(double &outPrice)
   {
      if(m_swingLowCount > 0)
      {
         outPrice = m_swingLows[0].price;
         return true;
      }
      return false;
   }
   
   //---------------------------------------------------------------------
   // Detect if price is near a key level (within X pips)
   //---------------------------------------------------------------------
   bool IsPriceNearKeyLevel(double tolerancePips = 30)
   {
      return GetDistanceToNearestLevel() <= tolerancePips && GetDistanceToNearestLevel() >= 0;
   }
   
   //---------------------------------------------------------------------
   // Helper: Convert Pips to USD
   //---------------------------------------------------------------------
   double PointsToUSD(double points)
   {
      return points * m_tick_size * SymbolInfoDouble(m_symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   }
};

//================================================================================
#endif // __KEYLEVELDETECTION_MQH__
//================================================================================
