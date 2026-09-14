//================================================================================
// Gold MTF Key-Level & Structure Breakout EA
// RiskManagement.mqh - Position Sizing, SL/TP Calculation & R:R Validation
// Purpose: Dynamic lot sizing, risk calculation, and reward validation
//================================================================================

#ifndef __RISKMANAGEMENT_MQH__
#define __RISKMANAGEMENT_MQH__

#include "Config.mqh"

//================================================================================
// CLASS: CRiskManagement
// Purpose: Handle all risk calculations, lot sizing, and R:R validation
//================================================================================

class CRiskManagement
{
private:
   string m_symbol;
   double m_symbol_point;
   double m_tick_size;
   double m_contract_size;
   
   ENUM_RISK_MODE m_riskMode;
   double m_riskValue;  // Either % or USD
   double m_minRiskReward;
   int m_slBufferPoints;
   
   // Account information (cached)
   double m_accountBalance;
   double m_equity;
   double m_freeMargin;
   int m_leverage;
   
   // Broker limits (cached)
   int m_stopLevel;
   int m_freezeLevel;
   double m_minLot;
   double m_maxLot;
   double m_lotStep;

public:
   //---------------------------------------------------------------------
   // Constructor
   //---------------------------------------------------------------------
   CRiskManagement(ENUM_RISK_MODE riskMode, double riskValue, double minRiskReward, int slBufferPoints)
   {
      m_symbol = Symbol();
      m_symbol_point = Point();
      m_tick_size = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
      m_contract_size = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_CONTRACT_SIZE);
      
      m_riskMode = riskMode;
      m_riskValue = riskValue;
      m_minRiskReward = minRiskReward;
      m_slBufferPoints = slBufferPoints;
      
      // Initialize account data
      UpdateAccountInfo();
      
      // Initialize broker limits
      UpdateBrokerLimits();
   }
   
   //---------------------------------------------------------------------
   // Destructor
   //---------------------------------------------------------------------
   ~CRiskManagement()
   {
   }
   
   //---------------------------------------------------------------------
   // Update Account Information (call on OnTick or periodically)
   //---------------------------------------------------------------------
   void UpdateAccountInfo()
   {
      m_accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      m_equity = AccountInfoDouble(ACCOUNT_EQUITY);
      m_freeMargin = AccountInfoDouble(ACCOUNT_FREEMARGIN);
      m_leverage = (int)AccountInfoInteger(ACCOUNT_LEVERAGE);
   }
   
   //---------------------------------------------------------------------
   // Update Broker Limits (call once on OnInit or when symbol changes)
   //---------------------------------------------------------------------
   void UpdateBrokerLimits()
   {
      m_stopLevel = (int)SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL);
      m_freezeLevel = (int)SymbolInfoInteger(m_symbol, SYMBOL_TRADE_FREEZE_LEVEL);
      
      m_minLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
      m_maxLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
      m_lotStep = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
   }
   
   //---------------------------------------------------------------------
   // Calculate Risk Amount in USD
   // Based on Risk Mode: Percent of Balance or Fixed Money
   //---------------------------------------------------------------------
   double CalculateRiskAmount()
   {
      if(m_riskMode == RISK_PERCENT)
      {
         // Risk as percentage of account balance
         double riskAmount = m_accountBalance * (m_riskValue / 100.0);
         return riskAmount;
      }
      else if(m_riskMode == RISK_FIXED_MONEY)
      {
         // Risk as fixed USD amount
         return m_riskValue;
      }
      
      return 0;
   }
   
   //---------------------------------------------------------------------
   // Calculate Lot Size based on SL distance and risk amount
   // Formula: Lot = Risk Amount / (SL Distance in pips * Tick Value)
   //---------------------------------------------------------------------
   double CalculateLotSize(double entryPrice, double stopLossPrice)
   {
      // Validate prices
      if(entryPrice <= 0 || stopLossPrice <= 0)
         return 0;
      
      // Calculate SL distance in pips
      double slDistancePips = MathAbs(entryPrice - stopLossPrice) / m_symbol_point;
      
      if(slDistancePips <= 0)
         return 0;
      
      // Get risk amount
      double riskAmount = CalculateRiskAmount();
      
      // Tick value = price movement per pip * contract size
      double tickValue = m_tick_size * m_contract_size;
      
      // Calculate raw lot size
      double rawLots = riskAmount / (slDistancePips * tickValue);
      
      // Normalize to broker's lot step
      double normalizedLots = NormalizeLotSize(rawLots);
      
      return normalizedLots;
   }
   
   //---------------------------------------------------------------------
   // Normalize lot size to broker's requirements
   // Apply min/max limits and lot step increments
   //---------------------------------------------------------------------
   double NormalizeLotSize(double rawLots)
   {
      // Clamp to broker's min/max
      if(rawLots < m_minLot)
         return m_minLot;
      
      if(rawLots > m_maxLot)
         return m_maxLot;
      
      // Round down to nearest lot step
      double normalizedLots = MathFloor(rawLots / m_lotStep) * m_lotStep;
      
      return normalizedLots;
   }
   
   //---------------------------------------------------------------------
   // Calculate Stop Loss Price
   // For BUY: SL = Last Swing Low - Buffer
   // For SELL: SL = Last Swing High + Buffer
   //---------------------------------------------------------------------
   double CalculateStopLoss(bool isBuy, double invalidationLevel)
   {
      // Add buffer points beyond invalidation level
      double bufferDistance = m_slBufferPoints * m_symbol_point;
      
      if(isBuy)
      {
         // For buy: SL is below invalidation level
         return invalidationLevel - bufferDistance;
      }
      else
      {
         // For sell: SL is above invalidation level
         return invalidationLevel + bufferDistance;
      }
   }
   
   //---------------------------------------------------------------------
   // Validate Stop Loss against Broker's Minimum Stop Level
   // Returns: True if SL distance is valid, False if too close to entry
   //---------------------------------------------------------------------
   bool ValidateStopLoss(double entryPrice, double stopLossPrice)
   {
      double slDistancePoints = MathAbs(entryPrice - stopLossPrice) / m_symbol_point;
      
      // Broker's StopsLevel is in points
      if(slDistancePoints < m_stopLevel)
      {
         return false;  // SL too close to entry
      }
      
      return true;
   }
   
   //---------------------------------------------------------------------
   // Calculate Take Profit Price
   // Targets: Next HTF Key Level OR R:R Multiplier (whichever is closer)
   // Default: Target = Entry + (SL Distance * R:R multiplier)
   //---------------------------------------------------------------------
   double CalculateTakeProfit(bool isBuy, double entryPrice, double stopLossPrice, double nextKeyLevel = 0)
   {
      double slDistance = MathAbs(entryPrice - stopLossPrice);
      double rrDistance = slDistance * m_minRiskReward;
      
      double tpPrice;
      
      if(isBuy)
      {
         // For buy: TP is above entry
         tpPrice = entryPrice + rrDistance;
         
         // If next key level is provided and is above TP, use key level as target
         if(nextKeyLevel > 0 && nextKeyLevel > tpPrice)
         {
            tpPrice = nextKeyLevel;
         }
      }
      else
      {
         // For sell: TP is below entry
         tpPrice = entryPrice - rrDistance;
         
         // If next key level is provided and is below TP, use key level as target
         if(nextKeyLevel > 0 && nextKeyLevel < tpPrice)
         {
            tpPrice = nextKeyLevel;
         }
      }
      
      return tpPrice;
   }
   
   //---------------------------------------------------------------------
   // Validate Risk-to-Reward Ratio
   // Returns: True if R:R >= Minimum R:R threshold (e.g., 1:2)
   //---------------------------------------------------------------------
   bool ValidateRiskRewardRatio(double entryPrice, double stopLossPrice, double takeProfitPrice)
   {
      // Calculate actual R:R
      double risk = MathAbs(entryPrice - stopLossPrice);
      double reward = MathAbs(takeProfitPrice - entryPrice);
      
      if(risk <= 0)
         return false;
      
      double actualRR = reward / risk;
      
      // Return true if actual R:R >= minimum required
      return actualRR >= m_minRiskReward;
   }
   
   //---------------------------------------------------------------------
   // Calculate Actual Risk-to-Reward Ratio
   // Returns: Ratio as double (e.g., 2.0 for 1:2)
   //---------------------------------------------------------------------
   double GetActualRiskRewardRatio(double entryPrice, double stopLossPrice, double takeProfitPrice)
   {
      double risk = MathAbs(entryPrice - stopLossPrice);
      double reward = MathAbs(takeProfitPrice - entryPrice);
      
      if(risk <= 0)
         return 0;
      
      return reward / risk;
   }
   
   //---------------------------------------------------------------------
   // Calculate Risk Amount in USD for a specific trade
   // Risk = (Entry - SL) * Contract Size * Tick Value * Lot Size
   //---------------------------------------------------------------------
   double CalculateTradeRiskUSD(double entryPrice, double stopLossPrice, double lotSize)
   {
      double slDistancePips = MathAbs(entryPrice - stopLossPrice) / m_symbol_point;
      double tickValue = m_tick_size * m_contract_size;
      
      double riskUSD = slDistancePips * tickValue * lotSize;
      
      return riskUSD;
   }
   
   //---------------------------------------------------------------------
   // Calculate Reward Amount in USD for a specific trade
   // Reward = (TP - Entry) * Contract Size * Tick Value * Lot Size
   //---------------------------------------------------------------------
   double CalculateTradeRewardUSD(double entryPrice, double takeProfitPrice, double lotSize)
   {
      double tpDistancePips = MathAbs(takeProfitPrice - entryPrice) / m_symbol_point;
      double tickValue = m_tick_size * m_contract_size;
      
      double rewardUSD = tpDistancePips * tickValue * lotSize;
      
      return rewardUSD;
   }
   
   //---------------------------------------------------------------------
   // Validate Trade Against Broker's Spread Limit
   // Returns: True if current spread <= max allowed spread
   //---------------------------------------------------------------------
   bool ValidateSpreadLimit(int maxSpreadPoints)
   {
      double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      
      double currentSpread = (ask - bid) / m_symbol_point;
      
      return currentSpread <= maxSpreadPoints;
   }
   
   //---------------------------------------------------------------------
   // Get Current Spread in Points
   //---------------------------------------------------------------------
   double GetCurrentSpread()
   {
      double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      
      return (ask - bid) / m_symbol_point;
   }
   
   //---------------------------------------------------------------------
   // Validate Free Margin is sufficient for trade
   // Returns: True if enough margin available for lot size
   //---------------------------------------------------------------------
   bool ValidateFreeMargin(double lotSize)
   {
      // Get margin required per lot
      double marginPerLot = SymbolInfoDouble(m_symbol, SYMBOL_MARGIN_INITIAL);
      
      double requiredMargin = marginPerLot * lotSize;
      
      // Add buffer (use 90% of free margin to stay safe)
      double availableMargin = m_freeMargin * 0.90;
      
      return requiredMargin <= availableMargin;
   }
   
   //---------------------------------------------------------------------
   // Validate Entry Price Respects Broker's Freeze Level
   // Freeze level = distance price must be from pending orders
   // Returns: True if price is valid distance from last pending order
   //---------------------------------------------------------------------
   bool ValidateFreezeLevel(double entryPrice)
   {
      // For market orders this is less critical, but check anyway
      double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      double freezeDistance = MathAbs(entryPrice - currentPrice) / m_symbol_point;
      
      // If freeze level is set, validate
      if(m_freezeLevel > 0)
      {
         return freezeDistance >= m_freezeLevel;
      }
      
      return true;
   }
   
   //---------------------------------------------------------------------
   // Complete Trade Setup Validation
   // Validates all conditions before allowing entry
   //---------------------------------------------------------------------
   bool ValidateCompleteTradeSetup(
      double entryPrice,
      double stopLossPrice,
      double takeProfitPrice,
      double lotSize,
      int maxSpreadPoints
   )
   {
      // 1. Validate SL distance from entry
      if(!ValidateStopLoss(entryPrice, stopLossPrice))
         return false;
      
      // 2. Validate R:R ratio
      if(!ValidateRiskRewardRatio(entryPrice, stopLossPrice, takeProfitPrice))
         return false;
      
      // 3. Validate spread is within limits
      if(!ValidateSpreadLimit(maxSpreadPoints))
         return false;
      
      // 4. Validate free margin available
      if(!ValidateFreeMargin(lotSize))
         return false;
      
      // 5. Validate freeze level
      if(!ValidateFreezeLevel(entryPrice))
         return false;
      
      return true;
   }
   
   //---------------------------------------------------------------------
   // GETTER: Minimum SL Distance Required by Broker (in pips)
   //---------------------------------------------------------------------
   int GetMinimumStopLevel()
   {
      return m_stopLevel;
   }
   
   //---------------------------------------------------------------------
   // GETTER: Account Balance
   //---------------------------------------------------------------------
   double GetAccountBalance()
   {
      return m_accountBalance;
   }
   
   //---------------------------------------------------------------------
   // GETTER: Current Equity
   //---------------------------------------------------------------------
   double GetEquity()
   {
      return m_equity;
   }
   
   //---------------------------------------------------------------------
   // GETTER: Free Margin Available
   //---------------------------------------------------------------------
   double GetFreeMargin()
   {
      return m_freeMargin;
   }
   
   //---------------------------------------------------------------------
   // GETTER: Account Leverage
   //---------------------------------------------------------------------
   int GetLeverage()
   {
      return m_leverage;
   }
   
   //---------------------------------------------------------------------
   // GETTER: Minimum Lot Size (broker requirement)
   //---------------------------------------------------------------------
   double GetMinimumLotSize()
   {
      return m_minLot;
   }
   
   //---------------------------------------------------------------------
   // GETTER: Maximum Lot Size (broker limit)
   //---------------------------------------------------------------------
   double GetMaximumLotSize()
   {
      return m_maxLot;
   }
   
   //---------------------------------------------------------------------
   // GETTER: Lot Step
   //---------------------------------------------------------------------
   double GetLotStep()
   {
      return m_lotStep;
   }
   
   //---------------------------------------------------------------------
   // Calculate Maximum Lot Size based on current free margin
   // Useful for scaling entries
   //---------------------------------------------------------------------
   double CalculateMaxLotByMargin()
   {
      double marginPerLot = SymbolInfoDouble(m_symbol, SYMBOL_MARGIN_INITIAL);
      
      if(marginPerLot <= 0)
         return m_minLot;
      
      double maxLotByMargin = (m_freeMargin * 0.90) / marginPerLot;
      
      return NormalizeLotSize(maxLotByMargin);
   }
   
   //---------------------------------------------------------------------
   // Calculate Pip Value in USD for position sizing
   //---------------------------------------------------------------------
   double GetPipValueUSD(double lotSize)
   {
      double tickValue = m_tick_size * m_contract_size;
      return tickValue * lotSize;
   }
   
   //---------------------------------------------------------------------
   // Risk-Reward Summary Report
   // Useful for logging and validation
   //---------------------------------------------------------------------
   string GetTradeSetupSummary(
      double entryPrice,
      double stopLossPrice,
      double takeProfitPrice,
      double lotSize
   )
   {
      string summary = "";
      
      double riskUSD = CalculateTradeRiskUSD(entryPrice, stopLossPrice, lotSize);
      double rewardUSD = CalculateTradeRewardUSD(entryPrice, takeProfitPrice, lotSize);
      double rrRatio = GetActualRiskRewardRatio(entryPrice, stopLossPrice, takeProfitPrice);
      
      double slPips = MathAbs(entryPrice - stopLossPrice) / m_symbol_point;
      double tpPips = MathAbs(takeProfitPrice - entryPrice) / m_symbol_point;
      
      summary += "Entry: " + DoubleToString(entryPrice, 5) + " | ";
      summary += "SL: " + DoubleToString(stopLossPrice, 5) + " | ";
      summary += "TP: " + DoubleToString(takeProfitPrice, 5) + "\n";
      summary += "SL Distance: " + DoubleToString(slPips, 1) + " pips | ";
      summary += "TP Distance: " + DoubleToString(tpPips, 1) + " pips\n";
      summary += "Lot Size: " + DoubleToString(lotSize, 2) + " | ";
      summary += "Risk USD: $" + DoubleToString(riskUSD, 2) + " | ";
      summary += "Reward USD: $" + DoubleToString(rewardUSD, 2) + "\n";
      summary += "R:R Ratio: 1:" + DoubleToString(rrRatio, 2);
      
      return summary;
   }
   
   //---------------------------------------------------------------------
   // Adjust TP to respect next key level (don't exceed it)
   //---------------------------------------------------------------------
   double AdjustTPToKeyLevel(double takeProfitPrice, double nextKeyLevel, bool isBuy)
   {
      if(nextKeyLevel <= 0)
         return takeProfitPrice;
      
      if(isBuy)
      {
         // For buy: TP should not exceed next supply level
         if(takeProfitPrice > nextKeyLevel)
            return nextKeyLevel;
      }
      else
      {
         // For sell: TP should not go below next demand level
         if(takeProfitPrice < nextKeyLevel)
            return nextKeyLevel;
      }
      
      return takeProfitPrice;
   }
};

//================================================================================
#endif // __RISKMANAGEMENT_MQH__
//================================================================================
