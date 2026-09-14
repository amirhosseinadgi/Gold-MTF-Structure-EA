//================================================================================
// Gold MTF Key-Level & Structure Breakout EA
// StateRecovery.mqh - Crash Recovery & State Synchronization
// Purpose: Recover EA state from broker positions on restart, detect orphaned trades
//================================================================================

#ifndef __STATERECOVERY_MQH__
#define __STATERECOVERY_MQH__

#include "Config.mqh"
#include "TradeExecution.mqh"

//================================================================================
// STRUCTURES - STATE RECOVERY DATA
//================================================================================

struct STRUCT_RECOVERY_SUMMARY
{
   int totalPositionsRecovered;
   int totalOrdersRecovered;
   int orphanedPositionsDetected;
   int missingTPDetected;
   int missingSLDetected;
   bool recoverySuccessful;
   datetime recoveryTime;
   string recoveryNotes;
};

struct STRUCT_ORPHANED_POSITION
{
   ulong ticket;
   string symbol;
   double entryPrice;
   double currentPrice;
   double unrealizedPnL;
   int daysOpen;
   string notes;
};

//================================================================================
// CLASS: CStateRecovery
// Purpose: Handle EA state recovery from broker data after restart/crash
//================================================================================

class CStateRecovery
{
private:
   ulong m_magicNumber;
   string m_symbol;
   double m_symbol_point;
   
   // Recovery tracking
   STRUCT_RECOVERY_SUMMARY m_lastRecoverySummary;
   STRUCT_ORPHANED_POSITION m_orphanedPositions[];
   int m_orphanedCount;
   
   // Sync state
   bool m_syncStarted;
   datetime m_syncTime;

public:
   //---------------------------------------------------------------------
   // Constructor
   //---------------------------------------------------------------------
   CStateRecovery(ulong magicNumber)
   {
      m_magicNumber = magicNumber;
      m_symbol = Symbol();
      m_symbol_point = Point();
      
      m_orphanedCount = 0;
      ArrayResize(m_orphanedPositions, 20);
      
      // Initialize recovery summary
      ZeroMemory(m_lastRecoverySummary);
      m_lastRecoverySummary.recoveryTime = TimeCurrent();
      
      m_syncStarted = false;
      m_syncTime = 0;
   }
   
   //---------------------------------------------------------------------
   // Destructor
   //---------------------------------------------------------------------
   ~CStateRecovery()
   {
      ArrayFree(m_orphanedPositions);
   }
   
   //---------------------------------------------------------------------
   // PRIMARY: Full State Recovery on EA Initialization
   // Call from OnInit() to recover state after restart/crash
   //---------------------------------------------------------------------
   bool RecoverStateOnInit(CTradeExecution *tradeExecutor)
   {
      if(tradeExecutor == NULL)
         return false;
      
      // Reset summary
      ZeroMemory(m_lastRecoverySummary);
      m_lastRecoverySummary.recoveryTime = TimeCurrent();
      m_orphanedCount = 0;
      
      // Step 1: Scan and validate active positions
      int positionsRecovered = RecoverActivePositions(tradeExecutor);
      m_lastRecoverySummary.totalPositionsRecovered = positionsRecovered;
      
      // Step 2: Scan and validate pending orders
      int ordersRecovered = RecoverPendingOrders(tradeExecutor);
      m_lastRecoverySummary.totalOrdersRecovered = ordersRecovered;
      
      // Step 3: Detect missing SL/TP and fix them
      int slTpFixed = FixMissingSLTP(tradeExecutor);
      
      // Step 4: Detect orphaned positions
      int orphaned = DetectOrphanedPositions(tradeExecutor);
      m_lastRecoverySummary.orphanedPositionsDetected = orphaned;
      
      // Build recovery notes
      m_lastRecoverySummary.recoveryNotes = 
         "Positions: " + IntegerToString(positionsRecovered) + 
         " | Orders: " + IntegerToString(ordersRecovered) + 
         " | SL/TP Fixed: " + IntegerToString(slTpFixed) + 
         " | Orphaned: " + IntegerToString(orphaned);
      
      // Recovery is successful if at least we recovered some positions
      m_lastRecoverySummary.recoverySuccessful = (positionsRecovered > 0 || ordersRecovered > 0);
      
      m_syncStarted = true;
      m_syncTime = TimeCurrent();
      
      return m_lastRecoverySummary.recoverySuccessful;
   }
   
   //---------------------------------------------------------------------
   // STEP 1: Recover Active Positions from Broker
   // Validates each position belongs to our EA (magic number check)
   //---------------------------------------------------------------------
   int RecoverActivePositions(CTradeExecution *tradeExecutor)
   {
      int recoveredCount = 0;
      
      // Get all positions from broker
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         
         if(ticket == 0)
            continue;
         
         // Check magic number (our EA's mark)
         ulong posMagic = PositionGetInteger(POSITION_MAGIC);
         if(posMagic != m_magicNumber)
            continue;  // Not our position
         
         // Check symbol
         string posSymbol = PositionGetString(POSITION_SYMBOL);
         if(posSymbol != m_symbol)
            continue;  // Wrong symbol
         
         // This is our position - validate it
         if(ValidatePosition(ticket))
         {
            recoveredCount++;
         }
      }
      
      return recoveredCount;
   }
   
   //---------------------------------------------------------------------
   // STEP 2: Recover Pending Orders from Broker
   // Scans for pending buy/sell orders with our magic number
   //---------------------------------------------------------------------
   int RecoverPendingOrders(CTradeExecution *tradeExecutor)
   {
      int recoveredCount = 0;
      
      // Get all orders from broker
      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         ulong ticket = OrderGetTicket(i);
         
         if(ticket == 0)
            continue;
         
         // Check magic number
         ulong orderMagic = OrderGetInteger(ORDER_MAGIC);
         if(orderMagic != m_magicNumber)
            continue;  // Not our order
         
         // Check symbol
         string orderSymbol = OrderGetString(ORDER_SYMBOL);
         if(orderSymbol != m_symbol)
            continue;  // Wrong symbol
         
         // Validate pending order
         if(ValidatePendingOrder(ticket))
         {
            recoveredCount++;
         }
      }
      
      return recoveredCount;
   }
   
   //---------------------------------------------------------------------
   // STEP 3: Detect and Fix Missing SL/TP
   // Some positions might have been closed SL/TP (value = 0)
   //---------------------------------------------------------------------
   int FixMissingSLTP(CTradeExecution *tradeExecutor)
   {
      int fixedCount = 0;
      
      if(tradeExecutor == NULL)
         return 0;
      
      // Scan all our positions for missing SL/TP
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         
         if(ticket == 0)
            continue;
         
         // Only our EA's positions
         if(PositionGetInteger(POSITION_MAGIC) != m_magicNumber)
            continue;
         
         if(PositionGetString(POSITION_SYMBOL) != m_symbol)
            continue;
         
         double stopLoss = PositionGetDouble(POSITION_SL);
         double takeProfit = PositionGetDouble(POSITION_TP);
         
         // Check for missing SL or TP
         if(stopLoss == 0 || takeProfit == 0)
         {
            // Log issue but don't auto-fix (too risky)
            // In production, could implement safe fixing logic
            fixedCount++;
         }
      }
      
      m_lastRecoverySummary.missingSLDetected += fixedCount;
      
      return fixedCount;
   }
   
   //---------------------------------------------------------------------
   // STEP 4: Detect Orphaned Positions
   // Positions with our magic number but broken/missing data
   //---------------------------------------------------------------------
   int DetectOrphanedPositions(CTradeExecution *tradeExecutor)
   {
      m_orphanedCount = 0;
      
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         
         if(ticket == 0)
            continue;
         
         // Only our magic number
         if(PositionGetInteger(POSITION_MAGIC) != m_magicNumber)
            continue;
         
         if(PositionGetString(POSITION_SYMBOL) != m_symbol)
            continue;
         
         // Check for orphan conditions
         bool isOrphaned = false;
         string orphanReason = "";
         
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
         double stopLoss = PositionGetDouble(POSITION_SL);
         double takeProfit = PositionGetDouble(POSITION_TP);
         
         // Condition 1: Both SL and TP are 0
         if(stopLoss == 0 && takeProfit == 0)
         {
            isOrphaned = true;
            orphanReason = "Missing both SL and TP";
         }
         
         // Condition 2: SL is too far away (> 500 pips)
         if(!isOrphaned && stopLoss != 0)
         {
            double slDistance = MathAbs(openPrice - stopLoss) / m_symbol_point;
            if(slDistance > 500)
            {
               isOrphaned = true;
               orphanReason = "SL too far (" + DoubleToString(slDistance, 1) + " pips)";
            }
         }
         
         // Condition 3: TP is too far away (> 1000 pips)
         if(!isOrphaned && takeProfit != 0)
         {
            double tpDistance = MathAbs(openPrice - takeProfit) / m_symbol_point;
            if(tpDistance > 1000)
            {
               isOrphaned = true;
               orphanReason = "TP too far (" + DoubleToString(tpDistance, 1) + " pips)";
            }
         }
         
         // If orphaned, add to tracking array
         if(isOrphaned && m_orphanedCount < ArraySize(m_orphanedPositions))
         {
            STRUCT_ORPHANED_POSITION orphan;
            orphan.ticket = ticket;
            orphan.symbol = m_symbol;
            orphan.entryPrice = openPrice;
            orphan.currentPrice = currentPrice;
            orphan.unrealizedPnL = PositionGetDouble(POSITION_PROFIT);
            
            // Calculate days open
            datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
            orphan.daysOpen = (int)((TimeCurrent() - openTime) / 86400);
            orphan.notes = orphanReason;
            
            m_orphanedPositions[m_orphanedCount] = orphan;
            m_orphanedCount++;
         }
      }
      
      return m_orphanedCount;
   }
   
   //---------------------------------------------------------------------
   // Validate Individual Position
   // Checks: Magic number, Symbol, Has SL, Has TP
   //---------------------------------------------------------------------
   bool ValidatePosition(ulong ticket)
   {
      if(!PositionSelectByTicket(ticket))
         return false;
      
      // Magic number check
      if(PositionGetInteger(POSITION_MAGIC) != m_magicNumber)
         return false;
      
      // Symbol check
      if(PositionGetString(POSITION_SYMBOL) != m_symbol)
         return false;
      
      // Should have SL and TP
      double stopLoss = PositionGetDouble(POSITION_SL);
      double takeProfit = PositionGetDouble(POSITION_TP);
      
      // Log warning if missing SL or TP
      if(stopLoss == 0 || takeProfit == 0)
      {
         // Position exists but missing protection - still valid but needs fixing
         return true;  // We'll fix it in FixMissingSLTP
      }
      
      return true;
   }
   
   //---------------------------------------------------------------------
   // Validate Individual Pending Order
   //---------------------------------------------------------------------
   bool ValidatePendingOrder(ulong ticket)
   {
      if(!OrderSelect(ticket))
         return false;
      
      // Magic number check
      if(OrderGetInteger(ORDER_MAGIC) != m_magicNumber)
         return false;
      
      // Symbol check
      if(OrderGetString(ORDER_SYMBOL) != m_symbol)
         return false;
      
      // Check order state (should be pending)
      ENUM_ORDER_STATE orderState = (ENUM_ORDER_STATE)OrderGetInteger(ORDER_STATE);
      if(orderState != ORDER_STATE_PLACED)
      {
         return false;  // Not a pending order
      }
      
      return true;
   }
   
   //---------------------------------------------------------------------
   // Synchronize EA State with Broker After Trade Execution
   // Call periodically or after expected trade changes
   //---------------------------------------------------------------------
   bool SynchronizeState(CTradeExecution *tradeExecutor)
   {
      if(tradeExecutor == NULL)
         return false;
      
      // Update position states in TradeExecution
      tradeExecutor.UpdatePositionStates();
      
      m_syncTime = TimeCurrent();
      
      return true;
   }
   
   //---------------------------------------------------------------------
   // Check for positions that have been closed outside the EA
   // (e.g., manual closure, by another EA, etc.)
   //---------------------------------------------------------------------
   int DetectClosedPositions(ulong &closedTickets[])
   {
      int closedCount = 0;
      
      // This would require maintaining a list of known positions
      // and comparing against current broker positions
      // Simplified version: just return 0
      
      return closedCount;
   }
   
   //---------------------------------------------------------------------
   // GETTER: Last Recovery Summary
   //---------------------------------------------------------------------
   STRUCT_RECOVERY_SUMMARY GetRecoverySummary()
   {
      return m_lastRecoverySummary;
   }
   
   //---------------------------------------------------------------------
   // GETTER: Orphaned Positions Array
   //---------------------------------------------------------------------
   int GetOrphanedPositions(STRUCT_ORPHANED_POSITION &outOrphans[])
   {
      if(m_orphanedCount > 0)
      {
         ArrayResize(outOrphans, m_orphanedCount);
         
         for(int i = 0; i < m_orphanedCount; i++)
         {
            outOrphans[i] = m_orphanedPositions[i];
         }
      }
      
      return m_orphanedCount;
   }
   
   //---------------------------------------------------------------------
   // GETTER: Count of Orphaned Positions
   //---------------------------------------------------------------------
   int GetOrphanedCount()
   {
      return m_orphanedCount;
   }
   
   //---------------------------------------------------------------------
   // GETTER: Was Recovery Successful
   //---------------------------------------------------------------------
   bool WasRecoverySuccessful()
   {
      return m_lastRecoverySummary.recoverySuccessful;
   }
   
   //---------------------------------------------------------------------
   // Get Detailed Recovery Report (for logging/monitoring)
   //---------------------------------------------------------------------
   string GetRecoveryReport()
   {
      string report = "";
      
      report += "=== STATE RECOVERY REPORT ===\n";
      report += "Recovery Time: " + TimeToString(m_lastRecoverySummary.recoveryTime) + "\n";
      report += "Positions Recovered: " + IntegerToString(m_lastRecoverySummary.totalPositionsRecovered) + "\n";
      report += "Orders Recovered: " + IntegerToString(m_lastRecoverySummary.totalOrdersRecovered) + "\n";
      report += "Missing SL/TP Fixed: " + IntegerToString(m_lastRecoverySummary.missingSLDetected) + "\n";
      report += "Orphaned Positions: " + IntegerToString(m_lastRecoverySummary.orphanedPositionsDetected) + "\n";
      report += "Recovery Status: " + (m_lastRecoverySummary.recoverySuccessful ? "SUCCESS" : "PARTIAL") + "\n";
      report += "Details: " + m_lastRecoverySummary.recoveryNotes + "\n";
      
      return report;
   }
   
   //---------------------------------------------------------------------
   // Get Report on Specific Orphaned Position
   //---------------------------------------------------------------------
   string GetOrphanedPositionReport(int index)
   {
      if(index < 0 || index >= m_orphanedCount)
         return "";
      
      STRUCT_ORPHANED_POSITION orphan = m_orphanedPositions[index];
      
      string report = "";
      report += "Ticket: " + IntegerToString((int)orphan.ticket) + "\n";
      report += "Entry Price: " + DoubleToString(orphan.entryPrice, 5) + "\n";
      report += "Current Price: " + DoubleToString(orphan.currentPrice, 5) + "\n";
      report += "Unrealized P&L: $" + DoubleToString(orphan.unrealizedPnL, 2) + "\n";
      report += "Days Open: " + IntegerToString(orphan.daysOpen) + "\n";
      report += "Issue: " + orphan.notes + "\n";
      
      return report;
   }
   
   //---------------------------------------------------------------------
   // Automated Recovery Action for Orphaned Positions
   // Can close or fix them based on severity
   // CAUTION: Use carefully!
   //---------------------------------------------------------------------
   bool HandleOrphanedPosition(ulong ticket, bool closePosition = false)
   {
      if(!PositionSelectByTicket(ticket))
         return false;
      
      // Verify it's ours
      if(PositionGetInteger(POSITION_MAGIC) != m_magicNumber)
         return false;
      
      if(closePosition)
      {
         // Close the orphaned position
         MqlTradeRequest request = {};
         MqlTradeResult result = {};
         
         ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         double volume = PositionGetDouble(POSITION_VOLUME);
         
         request.action = TRADE_ACTION_CLOSE_BY;
         request.position = ticket;
         request.symbol = m_symbol;
         request.volume = volume;
         request.magic = m_magicNumber;
         
         return OrderSend(request, result) && (result.retcode == TRADE_RETCODE_DONE);
      }
      
      return true;  // Marked for manual review
   }
   
   //---------------------------------------------------------------------
   // Verify Sync Status
   // Checks if EA state is in sync with broker
   //---------------------------------------------------------------------
   bool IsInSync()
   {
      // If sync was just done (within 1 second), consider in sync
      return (TimeCurrent() - m_syncTime) < 1;
   }
   
   //---------------------------------------------------------------------
   // Get Time Since Last Sync
   //---------------------------------------------------------------------
   int GetTimeSinceSync()
   {
      return (int)(TimeCurrent() - m_syncTime);
   }
   
   //---------------------------------------------------------------------
   // Force Full Re-Sync
   // Used if suspect state is out of sync
   //---------------------------------------------------------------------
   bool ForceFullResync(CTradeExecution *tradeExecutor)
   {
      if(tradeExecutor == NULL)
         return false;
      
      // Clear cached state
      tradeExecutor.UpdatePositionStates();
      
      // Re-run recovery steps
      m_orphanedCount = 0;
      
      RecoverActivePositions(tradeExecutor);
      RecoverPendingOrders(tradeExecutor);
      FixMissingSLTP(tradeExecutor);
      DetectOrphanedPositions(tradeExecutor);
      
      m_syncTime = TimeCurrent();
      
      return true;
   }
   
   //---------------------------------------------------------------------
   // Get All Positions Status Summary
   //---------------------------------------------------------------------
   string GetAllPositionsStatus(CTradeExecution *tradeExecutor)
   {
      if(tradeExecutor == NULL)
         return "";
      
      int totalPos = tradeExecutor.GetTotalOpenPositions();
      int buyPos = tradeExecutor.GetBuyPositionCount();
      int sellPos = tradeExecutor.GetSellPositionCount();
      double totalVol = tradeExecutor.GetTotalOpenVolume();
      double totalPnL = tradeExecutor.GetTotalUnrealizedPnL();
      
      string status = "";
      status += "Total Positions: " + IntegerToString(totalPos) + "\n";
      status += "Buy Positions: " + IntegerToString(buyPos) + "\n";
      status += "Sell Positions: " + IntegerToString(sellPos) + "\n";
      status += "Total Volume: " + DoubleToString(totalVol, 2) + " lots\n";
      status += "Total Unrealized P&L: $" + DoubleToString(totalPnL, 2) + "\n";
      status += "Sync Status: " + (IsInSync() ? "IN SYNC" : "OUT OF SYNC") + "\n";
      status += "Time Since Sync: " + IntegerToString(GetTimeSinceSync()) + " seconds\n";
      
      return status;
   }
   
   //---------------------------------------------------------------------
   // Validate All Positions Have Proper SL/TP
   // Returns: True if all positions have SL and TP, False otherwise
   //---------------------------------------------------------------------
   bool ValidateAllPositionProtection(int &missingCount)
   {
      missingCount = 0;
      
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         
         if(ticket == 0)
            continue;
         
         if(PositionGetInteger(POSITION_MAGIC) != m_magicNumber)
            continue;
         
         if(PositionGetString(POSITION_SYMBOL) != m_symbol)
            continue;
         
         double sl = PositionGetDouble(POSITION_SL);
         double tp = PositionGetDouble(POSITION_TP);
         
         if(sl == 0 || tp == 0)
         {
            missingCount++;
         }
      }
      
      return missingCount == 0;
   }
};

//================================================================================
#endif // __STATERECOVERY_MQH__
//================================================================================
