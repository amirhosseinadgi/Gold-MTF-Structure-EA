//================================================================================
// Gold MTF Key-Level & Structure Breakout EA
// TradeExecution.mqh - Order Placement, Management & Position Scaling
// Purpose: Execute trades, manage SL/TP, handle re-entries, track positions
//================================================================================

#ifndef __TRADEEXECUTION_MQH__
#define __TRADEEXECUTION_MQH__

#include "Config.mqh"
#include "RiskManagement.mqh"

//================================================================================
// CLASS: CTradeExecution
// Purpose: Handle all order placement, modification, and position management
//================================================================================

class CTradeExecution
{
private:
   ulong m_magicNumber;
   string m_symbol;
   double m_symbol_point;
   string m_eaComment;
   
   // Position tracking
   STRUCT_POSITION_STATE m_positions[];
   int m_positionCount;
   int m_maxOpenPositions;
   
   // Trade execution parameters
   int m_slippagePoints;
   CRiskManagement *m_riskManager;
   
   // Retry logic
   static const int MAX_RETRIES = 3;
   static const int RETRY_DELAY_MS = 500;

public:
   //---------------------------------------------------------------------
   // Constructor
   //---------------------------------------------------------------------
   CTradeExecution(ulong magicNumber, string eaComment, int maxPositions, 
                   int slippagePoints, CRiskManagement *riskManager)
   {
      m_magicNumber = magicNumber;
      m_symbol = Symbol();
      m_symbol_point = Point();
      m_eaComment = eaComment;
      m_maxOpenPositions = MathMin(maxPositions, 3);  // Max 3 positions
      m_slippagePoints = slippagePoints;
      m_riskManager = riskManager;
      
      m_positionCount = 0;
      ArrayResize(m_positions, 50);
      
      // Load existing positions from broker
      UpdatePositionStates();
   }
   
   //---------------------------------------------------------------------
   // Destructor
   //---------------------------------------------------------------------
   ~CTradeExecution()
   {
      ArrayFree(m_positions);
   }
   
   //---------------------------------------------------------------------
   // Update Position States
   // Scans all open positions and tracks those with our Magic Number
   // Call on OnInit and periodically on OnTick
   //---------------------------------------------------------------------
   void UpdatePositionStates()
   {
      m_positionCount = 0;
      
      // Scan all open positions
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         
         if(ticket == 0)
            continue;
         
         // Check if this position belongs to our EA (by magic number)
         if(PositionGetInteger(POSITION_MAGIC) != m_magicNumber)
            continue;
         
         // Check if position is on our symbol
         if(PositionGetString(POSITION_SYMBOL) != m_symbol)
            continue;
         
         // Add to our position array
         if(m_positionCount >= ArraySize(m_positions))
            ArrayResize(m_positions, m_positionCount + 10);
         
         STRUCT_POSITION_STATE posState;
         posState.ticket = ticket;
         posState.posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         posState.entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         posState.currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
         posState.stopLoss = PositionGetDouble(POSITION_SL);
         posState.takeProfit = PositionGetDouble(POSITION_TP);
         posState.entryTime = (datetime)PositionGetInteger(POSITION_TIME);
         posState.riskAmount = MathAbs((posState.entryPrice - posState.stopLoss) / m_symbol_point * 
                                       SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE) * 
                                       SymbolInfoDouble(m_symbol, SYMBOL_TRADE_CONTRACT_SIZE) * 
                                       PositionGetDouble(POSITION_VOLUME));
         posState.rewardAmount = MathAbs((posState.takeProfit - posState.entryPrice) / m_symbol_point * 
                                        SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE) * 
                                        SymbolInfoDouble(m_symbol, SYMBOL_TRADE_CONTRACT_SIZE) * 
                                        PositionGetDouble(POSITION_VOLUME));
         posState.barsOpen = 0;  // Will be calculated in EA
         
         m_positions[m_positionCount] = posState;
         m_positionCount++;
      }
   }
   
   //---------------------------------------------------------------------
   // Execute Buy Entry Order
   // Returns: Ticket number if successful, 0 if failed
   //---------------------------------------------------------------------
   ulong ExecuteBuyEntry(double entryPrice, double stopLossPrice, double takeProfitPrice, 
                         double lotSize, string reason = "")
   {
      // Validate trade setup
      if(!m_riskManager.ValidateCompleteTradeSetup(entryPrice, stopLossPrice, takeProfitPrice, 
                                                     lotSize, (int)m_riskManager.GetCurrentSpread()))
      {
         return 0;  // Trade setup invalid
      }
      
      // Check if we can add more positions
      if(m_positionCount >= m_maxOpenPositions)
      {
         return 0;  // Already at max positions
      }
      
      // Prepare trade structure
      MqlTradeRequest request = {};
      MqlTradeResult result = {};
      
      request.action = TRADE_ACTION_BUY;
      request.symbol = m_symbol;
      request.volume = lotSize;
      request.price = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      request.sl = stopLossPrice;
      request.tp = takeProfitPrice;
      request.deviation = m_slippagePoints;
      request.magic = m_magicNumber;
      request.comment = m_eaComment + " | " + reason;
      request.type = ORDER_TYPE_BUY;
      request.type_filling = ORDER_FILLING_IOC;  // Fill or Kill
      
      // Execute with retry logic
      ulong ticket = ExecuteWithRetry(request, result);
      
      if(ticket > 0)
      {
         UpdatePositionStates();
      }
      
      return ticket;
   }
   
   //---------------------------------------------------------------------
   // Execute Sell Entry Order
   // Returns: Ticket number if successful, 0 if failed
   //---------------------------------------------------------------------
   ulong ExecuteSellEntry(double entryPrice, double stopLossPrice, double takeProfitPrice, 
                          double lotSize, string reason = "")
   {
      // Validate trade setup
      if(!m_riskManager.ValidateCompleteTradeSetup(entryPrice, stopLossPrice, takeProfitPrice, 
                                                     lotSize, (int)m_riskManager.GetCurrentSpread()))
      {
         return 0;  // Trade setup invalid
      }
      
      // Check if we can add more positions
      if(m_positionCount >= m_maxOpenPositions)
      {
         return 0;  // Already at max positions
      }
      
      // Prepare trade structure
      MqlTradeRequest request = {};
      MqlTradeResult result = {};
      
      request.action = TRADE_ACTION_SELL;
      request.symbol = m_symbol;
      request.volume = lotSize;
      request.price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      request.sl = stopLossPrice;
      request.tp = takeProfitPrice;
      request.deviation = m_slippagePoints;
      request.magic = m_magicNumber;
      request.comment = m_eaComment + " | " + reason;
      request.type = ORDER_TYPE_SELL;
      request.type_filling = ORDER_FILLING_IOC;  // Fill or Kill
      
      // Execute with retry logic
      ulong ticket = ExecuteWithRetry(request, result);
      
      if(ticket > 0)
      {
         UpdatePositionStates();
      }
      
      return ticket;
   }
   
   //---------------------------------------------------------------------
   // Execute Trade with Retry Logic
   // Attempts to execute order up to MAX_RETRIES times
   //---------------------------------------------------------------------
   ulong ExecuteWithRetry(MqlTradeRequest &request, MqlTradeResult &result)
   {
      for(int attempt = 0; attempt < MAX_RETRIES; attempt++)
      {
         ZeroMemory(result);
         
         if(OrderSend(request, result))
         {
            // Order placed successfully
            if(result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_PLACED)
            {
               return result.order;
            }
         }
         
         // If not last attempt, wait before retry
         if(attempt < MAX_RETRIES - 1)
         {
            Sleep(RETRY_DELAY_MS);
         }
      }
      
      return 0;  // All retries failed
   }
   
   //---------------------------------------------------------------------
   // Modify Position Stop Loss and Take Profit
   // Returns: True if modification successful, False otherwise
   //---------------------------------------------------------------------
   bool ModifyPosition(ulong ticket, double newSL, double newTP)
   {
      if(!PositionSelectByTicket(ticket))
         return false;
      
      // Ensure position is ours
      if(PositionGetInteger(POSITION_MAGIC) != m_magicNumber)
         return false;
      
      MqlTradeRequest request = {};
      MqlTradeResult result = {};
      
      request.action = TRADE_ACTION_SLTP;
      request.position = ticket;
      request.symbol = m_symbol;
      request.sl = newSL;
      request.tp = newTP;
      request.magic = m_magicNumber;
      
      // Execute with retry logic
      if(ExecuteWithRetry(request, result) > 0)
      {
         return true;
      }
      
      return false;
   }
   
   //---------------------------------------------------------------------
   // Modify Only Stop Loss (keep TP unchanged)
   //---------------------------------------------------------------------
   bool ModifyStopLoss(ulong ticket, double newSL)
   {
      if(!PositionSelectByTicket(ticket))
         return false;
      
      double currentTP = PositionGetDouble(POSITION_TP);
      
      return ModifyPosition(ticket, newSL, currentTP);
   }
   
   //---------------------------------------------------------------------
   // Modify Only Take Profit (keep SL unchanged)
   //---------------------------------------------------------------------
   bool ModifyTakeProfit(ulong ticket, double newTP)
   {
      if(!PositionSelectByTicket(ticket))
         return false;
      
      double currentSL = PositionGetDouble(POSITION_SL);
      
      return ModifyPosition(ticket, currentSL, newTP);
   }
   
   //---------------------------------------------------------------------
   // Partial Close of Position
   // Close a percentage or fixed volume of an open position
   //---------------------------------------------------------------------
   bool PartialClose(ulong ticket, double volumeToClose)
   {
      if(!PositionSelectByTicket(ticket))
         return false;
      
      if(PositionGetInteger(POSITION_MAGIC) != m_magicNumber)
         return false;
      
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double currentVolume = PositionGetDouble(POSITION_VOLUME);
      
      // Ensure closing volume is less than total
      if(volumeToClose >= currentVolume)
         return false;
      
      MqlTradeRequest request = {};
      MqlTradeResult result = {};
      
      request.action = TRADE_ACTION_CLOSE_BY;
      request.position = ticket;
      request.symbol = m_symbol;
      request.volume = volumeToClose;
      request.magic = m_magicNumber;
      
      if(posType == OP_BUY)
         request.type = ORDER_TYPE_SELL;
      else
         request.type = ORDER_TYPE_BUY;
      
      return ExecuteWithRetry(request, result) > 0;
   }
   
   //---------------------------------------------------------------------
   // Close Position Completely
   //---------------------------------------------------------------------
   bool ClosePosition(ulong ticket)
   {
      if(!PositionSelectByTicket(ticket))
         return false;
      
      if(PositionGetInteger(POSITION_MAGIC) != m_magicNumber)
         return false;
      
      double volume = PositionGetDouble(POSITION_VOLUME);
      
      MqlTradeRequest request = {};
      MqlTradeResult result = {};
      
      request.action = TRADE_ACTION_CLOSE_BY;
      request.position = ticket;
      request.symbol = m_symbol;
      request.volume = volume;
      request.magic = m_magicNumber;
      
      return ExecuteWithRetry(request, result) > 0;
   }
   
   //---------------------------------------------------------------------
   // Close All Positions (for Friday close or emergency shutdown)
   //---------------------------------------------------------------------
   int CloseAllPositions()
   {
      int closedCount = 0;
      UpdatePositionStates();
      
      for(int i = 0; i < m_positionCount; i++)
      {
         if(ClosePosition(m_positions[i].ticket))
         {
            closedCount++;
         }
      }
      
      UpdatePositionStates();
      return closedCount;
   }
   
   //---------------------------------------------------------------------
   // Check if we can add another position (scaling-in)
   // Returns: True if position count < max allowed
   //---------------------------------------------------------------------
   bool CanAddPosition()
   {
      return m_positionCount < m_maxOpenPositions;
   }
   
   //---------------------------------------------------------------------
   // Get count of open Buy positions
   //---------------------------------------------------------------------
   int GetBuyPositionCount()
   {
      int buyCount = 0;
      
      for(int i = 0; i < m_positionCount; i++)
      {
         if(m_positions[i].posType == POS_LONG)
            buyCount++;
      }
      
      return buyCount;
   }
   
   //---------------------------------------------------------------------
   // Get count of open Sell positions
   //---------------------------------------------------------------------
   int GetSellPositionCount()
   {
      int sellCount = 0;
      
      for(int i = 0; i < m_positionCount; i++)
      {
         if(m_positions[i].posType == POS_SHORT)
            sellCount++;
      }
      
      return sellCount;
   }
   
   //---------------------------------------------------------------------
   // Get total open positions (both buy and sell)
   //---------------------------------------------------------------------
   int GetTotalOpenPositions()
   {
      return m_positionCount;
   }
   
   //---------------------------------------------------------------------
   // Get total volume across all positions
   //---------------------------------------------------------------------
   double GetTotalOpenVolume()
   {
      double totalVolume = 0;
      
      for(int i = 0; i < m_positionCount; i++)
      {
         if(PositionSelectByTicket(m_positions[i].ticket))
         {
            totalVolume += PositionGetDouble(POSITION_VOLUME);
         }
      }
      
      return totalVolume;
   }
   
   //---------------------------------------------------------------------
   // Get total unrealized P&L across all positions
   //---------------------------------------------------------------------
   double GetTotalUnrealizedPnL()
   {
      double totalPnL = 0;
      
      for(int i = 0; i < m_positionCount; i++)
      {
         if(PositionSelectByTicket(m_positions[i].ticket))
         {
            totalPnL += PositionGetDouble(POSITION_PROFIT);
         }
      }
      
      return totalPnL;
   }
   
   //---------------------------------------------------------------------
   // Get Highest Entry Price among Buy Positions
   // Used for scaling-in logic
   //---------------------------------------------------------------------
   double GetHighestBuyEntry()
   {
      double highest = 0;
      
      for(int i = 0; i < m_positionCount; i++)
      {
         if(m_positions[i].posType == POS_LONG)
         {
            if(m_positions[i].entryPrice > highest)
               highest = m_positions[i].entryPrice;
         }
      }
      
      return highest;
   }
   
   //---------------------------------------------------------------------
   // Get Lowest Entry Price among Sell Positions
   // Used for scaling-in logic
   //---------------------------------------------------------------------
   double GetLowestSellEntry()
   {
      double lowest = DBL_MAX;
      
      for(int i = 0; i < m_positionCount; i++)
      {
         if(m_positions[i].posType == POS_SHORT)
         {
            if(m_positions[i].entryPrice < lowest)
               lowest = m_positions[i].entryPrice;
         }
      }
      
      return (lowest == DBL_MAX) ? 0 : lowest;
   }
   
   //---------------------------------------------------------------------
   // Check if Re-entry is Valid (for scaling-in)
   // Criteria: Price must retest newly formed untested level
   // Direction: Must be in direction of primary trend
   //---------------------------------------------------------------------
   bool IsValidReentryLevel(bool isBuy, double retestLevel, double currentPrice, double tolerancePips = 10)
   {
      double distance = MathAbs(currentPrice - retestLevel) / m_symbol_point;
      
      if(isBuy)
      {
         // For buy re-entry: current price must be above retest level
         // And within tolerance (price approaching/touching the level)
         return currentPrice >= retestLevel && distance <= tolerancePips;
      }
      else
      {
         // For sell re-entry: current price must be below retest level
         // And within tolerance (price approaching/touching the level)
         return currentPrice <= retestLevel && distance <= tolerancePips;
      }
   }
   
   //---------------------------------------------------------------------
   // Attempt Scaling-In Entry (re-entry at newly formed level)
   // Returns: Ticket if successful, 0 if failed
   //---------------------------------------------------------------------
   ulong AttemptScalingEntry(bool isBuy, double scalePrice, double stopLossPrice, 
                             double takeProfitPrice, double lotSize, string reason = "")
   {
      // Can only scale if we already have position(s) in same direction
      if(isBuy && GetBuyPositionCount() == 0)
         return 0;
      if(!isBuy && GetSellPositionCount() == 0)
         return 0;
      
      // Can only scale if not at max positions
      if(!CanAddPosition())
         return 0;
      
      if(isBuy)
      {
         return ExecuteBuyEntry(scalePrice, stopLossPrice, takeProfitPrice, lotSize, reason);
      }
      else
      {
         return ExecuteSellEntry(scalePrice, stopLossPrice, takeProfitPrice, lotSize, reason);
      }
   }
   
   //---------------------------------------------------------------------
   // Move Stop Loss to Breakeven After Certain Profit Level
   // Useful for protecting profits on scaled-in positions
   //---------------------------------------------------------------------
   bool MoveToBreakeven(ulong ticket, double profitTarget)
   {
      if(!PositionSelectByTicket(ticket))
         return false;
      
      double currentProfit = PositionGetDouble(POSITION_PROFIT);
      double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      
      // Only move to BE if profit target reached
      if(currentProfit >= profitTarget)
      {
         return ModifyStopLoss(ticket, entryPrice);
      }
      
      return false;
   }
   
   //---------------------------------------------------------------------
   // Trail Stop Loss (move SL to follow price by certain distance)
   //---------------------------------------------------------------------
   bool TrailStopLoss(ulong ticket, double trailPoints)
   {
      if(!PositionSelectByTicket(ticket))
         return false;
      
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      double currentSL = PositionGetDouble(POSITION_SL);
      
      if(posType == POS_LONG)
      {
         // For long: new SL = current price - trail distance
         double newSL = currentPrice - (trailPoints * m_symbol_point);
         
         // Only move if new SL is higher than current SL
         if(newSL > currentSL)
         {
            return ModifyStopLoss(ticket, newSL);
         }
      }
      else if(posType == POS_SHORT)
      {
         // For short: new SL = current price + trail distance
         double newSL = currentPrice + (trailPoints * m_symbol_point);
         
         // Only move if new SL is lower than current SL
         if(newSL < currentSL)
         {
            return ModifyStopLoss(ticket, newSL);
         }
      }
      
      return false;
   }
   
   //---------------------------------------------------------------------
   // Get Position Details by Ticket
   //---------------------------------------------------------------------
   bool GetPositionDetails(ulong ticket, STRUCT_POSITION_STATE &outPos)
   {
      for(int i = 0; i < m_positionCount; i++)
      {
         if(m_positions[i].ticket == ticket)
         {
            outPos = m_positions[i];
            return true;
         }
      }
      
      return false;
   }
   
   //---------------------------------------------------------------------
   // Get All Open Positions Array
   //---------------------------------------------------------------------
   int GetAllPositions(STRUCT_POSITION_STATE &outPositions[])
   {
      if(m_positionCount > 0)
      {
         ArrayResize(outPositions, m_positionCount);
         
         for(int i = 0; i < m_positionCount; i++)
         {
            outPositions[i] = m_positions[i];
         }
      }
      
      return m_positionCount;
   }
   
   //---------------------------------------------------------------------
   // Check if Position Has Reached Take Profit
   //---------------------------------------------------------------------
   bool HasReachedTP(ulong ticket)
   {
      if(!PositionSelectByTicket(ticket))
         return false;
      
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      double takeProfit = PositionGetDouble(POSITION_TP);
      
      if(posType == POS_LONG)
         return currentPrice >= takeProfit;
      else
         return currentPrice <= takeProfit;
   }
   
   //---------------------------------------------------------------------
   // Check if Position Has Hit Stop Loss
   //---------------------------------------------------------------------
   bool HasHitSL(ulong ticket)
   {
      if(!PositionSelectByTicket(ticket))
         return false;
      
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      double stopLoss = PositionGetDouble(POSITION_SL);
      
      if(posType == POS_LONG)
         return currentPrice <= stopLoss;
      else
         return currentPrice >= stopLoss;
   }
   
   //---------------------------------------------------------------------
   // Get Position Profit in Pips
   //---------------------------------------------------------------------
   double GetPositionProfitPips(ulong ticket)
   {
      if(!PositionSelectByTicket(ticket))
         return 0;
      
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      
      if(posType == POS_LONG)
         return (currentPrice - entryPrice) / m_symbol_point;
      else
         return (entryPrice - currentPrice) / m_symbol_point;
   }
   
   //---------------------------------------------------------------------
   // Get all tickets for positions in a given direction
   //---------------------------------------------------------------------
   int GetPositionTickets(bool isBuy, ulong &outTickets[])
   {
      int ticketCount = 0;
      
      for(int i = 0; i < m_positionCount; i++)
      {
         if((isBuy && m_positions[i].posType == POS_LONG) || 
            (!isBuy && m_positions[i].posType == POS_SHORT))
         {
            if(ticketCount >= ArraySize(outTickets))
               ArrayResize(outTickets, ticketCount + 10);
            
            outTickets[ticketCount] = m_positions[i].ticket;
            ticketCount++;
         }
      }
      
      return ticketCount;
   }
};

//================================================================================
#endif // __TRADEEXECUTION_MQH__
//================================================================================
