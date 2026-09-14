//================================================================================
// Gold MTF Key-Level & Structure Breakout EA
// GoldMTFStructureEA.mq5 - Main Expert Advisor
// Purpose: Orchestrate all modules for multi-timeframe structure trading on Gold
//================================================================================

#property copyright "Copyright 2026"
#property link      "https://github.com/amirhosseinadgi/Gold-MTF-Structure-EA"
#property version   "1.00"
#property strict
#property description "Gold MTF Key-Level & Structure Breakout EA - Full Integration"

// Include all modules
#include <Trade\Trade.mqh>
#include "Include/Config.mqh"
#include "Include/KeyLevelDetection.mqh"
#include "Include/TrendBiasAnalysis.mqh"
#include "Include/PatternRecognition.mqh"
#include "Include/MomentumAnalysis.mqh"
#include "Include/RiskManagement.mqh"
#include "Include/TradeExecution.mqh"
#include "Include/StateRecovery.mqh"

//================================================================================
// GLOBAL MODULE INSTANCES
//================================================================================

CKeyLevelDetection *g_keyLevelStructure;      // HTF (D1) key levels
CKeyLevelDetection *g_keyLevelConfirm;        // Confirm TF (H4) key levels
CKeyLevelDetection *g_keyLevelEntry;          // Entry TF (H1) key levels

CTrendBiasAnalysis *g_trendAnalysis;          // Multi-TF trend bias

CPatternRecognition *g_patternStructure;      // HTF pattern detection
CPatternRecognition *g_patternConfirm;        // Confirm TF patterns

CMomentumAnalysis *g_momentumAnalysis;        // Entry TF momentum

CRiskManagement *g_riskManager;               // Position sizing & R:R validation

CTradeExecution *g_tradeExecutor;             // Order execution & management

CStateRecovery *g_stateRecovery;              // Crash recovery

//================================================================================
// EA STATE VARIABLES
//================================================================================

bool g_initialized = false;
bool g_newBarStructure = false;
bool g_newBarConfirm = false;
bool g_newBarEntry = false;

datetime g_lastBarStructure = 0;
datetime g_lastBarConfirm = 0;
datetime g_lastBarEntry = 0;

int g_tradesThisBar = 0;                      // Prevent multiple trades per bar
int g_debugPrintLevel = LOG_LEVEL_INFO;       // Debug output verbosity

//================================================================================
// OnInit - EA Initialization
//================================================================================

int OnInit()
{
   Print("=== GoldMTFStructureEA v1.00 - INITIALIZING ===");
   Print("Symbol: ", Symbol(), " | Account: ", AccountInfoInteger(ACCOUNT_LOGIN));
   
   // Step 1: Validate Input Parameters
   if(!ValidateInputParameters())
   {
      Print("ERROR: Input parameter validation failed!");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   // Step 2: Initialize All Modules
   if(!InitializeModules())
   {
      Print("ERROR: Module initialization failed!");
      return INIT_FAILED;
   }
   
   // Step 3: State Recovery (restore positions from broker)
   if(!PerformStateRecovery())
   {
      Print("WARNING: State recovery encountered issues, but continuing...");
      // Don't abort - might be first run
   }
   
   // Step 4: Set up chart objects for visualization (optional)
   SetupChartObjects();
   
   g_initialized = true;
   
   Print("=== EA INITIALIZATION SUCCESSFUL ===");
   Print("Ready to start trading on ", Symbol());
   
   return INIT_SUCCEEDED;
}

//================================================================================
// Validate Input Parameters
//================================================================================

bool ValidateInputParameters()
{
   // Validate timeframe hierarchy
   if(InpStructureTimeframe <= InpConfirmTimeframe || 
      InpConfirmTimeframe <= InpEntryTimeframe)
   {
      Print("ERROR: Timeframe hierarchy invalid! Must be Structure > Confirm > Entry");
      Print("Got: ", InpStructureTimeframe, " > ", InpConfirmTimeframe, " > ", InpEntryTimeframe);
      return false;
   }
   
   // Validate risk parameters
   if(InpRiskValue <= 0)
   {
      Print("ERROR: Risk value must be > 0");
      return false;
   }
   
   if(InpMinRiskReward < 1.0)
   {
      Print("ERROR: Minimum R:R ratio must be >= 1.0");
      return false;
   }
   
   // Validate position limits
   if(InpMaxOpenPositions < 1 || InpMaxOpenPositions > 3)
   {
      Print("ERROR: Max open positions must be 1-3");
      return false;
   }
   
   // Validate swing lookback
   if(InpSwingLookback < 3 || InpSwingLookback > 10)
   {
      Print("ERROR: Swing lookback must be 3-10");
      return false;
   }
   
   Print("✓ Input parameters validated successfully");
   return true;
}

//================================================================================
// Initialize All Modules
//================================================================================

bool InitializeModules()
{
   Print("Initializing Key Level Detection...");
   g_keyLevelStructure = new CKeyLevelDetection(InpStructureTimeframe, InpSwingLookback, InpMinLevelDistance);
   g_keyLevelConfirm = new CKeyLevelDetection(InpConfirmTimeframe, InpSwingLookback, InpMinLevelDistance);
   g_keyLevelEntry = new CKeyLevelDetection(InpEntryTimeframe, InpSwingLookback, InpMinLevelDistance);
   
   if(g_keyLevelStructure == NULL || g_keyLevelConfirm == NULL || g_keyLevelEntry == NULL)
   {
      Print("ERROR: Failed to create KeyLevelDetection instances");
      return false;
   }
   
   Print("Initializing Trend Analysis...");
   g_trendAnalysis = new CTrendBiasAnalysis(InpStructureTimeframe, InpConfirmTimeframe, InpEntryTimeframe);
   
   if(g_trendAnalysis == NULL)
   {
      Print("ERROR: Failed to create TrendBiasAnalysis instance");
      return false;
   }
   
   Print("Initializing Pattern Recognition...");
   g_patternStructure = new CPatternRecognition(InpStructureTimeframe);
   g_patternConfirm = new CPatternRecognition(InpConfirmTimeframe);
   
   if(g_patternStructure == NULL || g_patternConfirm == NULL)
   {
      Print("ERROR: Failed to create PatternRecognition instances");
      return false;
   }
   
   Print("Initializing Momentum Analysis...");
   g_momentumAnalysis = new CMomentumAnalysis(InpEntryTimeframe);
   
   if(g_momentumAnalysis == NULL)
   {
      Print("ERROR: Failed to create MomentumAnalysis instance");
      return false;
   }
   
   Print("Initializing Risk Management...");
   g_riskManager = new CRiskManagement(InpRiskMode, InpRiskValue, InpMinRiskReward, InpSLBufferPoints);
   
   if(g_riskManager == NULL)
   {
      Print("ERROR: Failed to create RiskManagement instance");
      return false;
   }
   
   Print("Initializing Trade Execution...");
   g_tradeExecutor = new CTradeExecution(InpMagicNumber, InpEAComment, InpMaxOpenPositions, 
                                          InpSlippagePoints, g_riskManager);
   
   if(g_tradeExecutor == NULL)
   {
      Print("ERROR: Failed to create TradeExecution instance");
      return false;
   }
   
   Print("Initializing State Recovery...");
   g_stateRecovery = new CStateRecovery(InpMagicNumber);
   
   if(g_stateRecovery == NULL)
   {
      Print("ERROR: Failed to create StateRecovery instance");
      return false;
   }
   
   Print("✓ All modules initialized successfully");
   return true;
}

//================================================================================
// Perform State Recovery
//================================================================================

bool PerformStateRecovery()
{
   Print("Attempting state recovery from broker...");
   
   if(g_stateRecovery == NULL || g_tradeExecutor == NULL)
   {
      Print("ERROR: Recovery modules not initialized");
      return false;
   }
   
   // Run full recovery
   bool recoverySuccess = g_stateRecovery.RecoverStateOnInit(g_tradeExecutor);
   
   // Get and log recovery summary
   STRUCT_RECOVERY_SUMMARY summary = g_stateRecovery.GetRecoverySummary();
   
   Print("State Recovery Summary:");
   Print("  Positions Recovered: ", summary.totalPositionsRecovered);
   Print("  Orders Recovered: ", summary.totalOrdersRecovered);
   Print("  Orphaned Detected: ", summary.orphanedPositionsDetected);
   Print("  Status: ", (summary.recoverySuccessful ? "SUCCESS" : "PARTIAL"));
   
   // Check for orphaned positions
   if(summary.orphanedPositionsDetected > 0)
   {
      Print("WARNING: Orphaned positions detected - review manually!");
      
      STRUCT_ORPHANED_POSITION orphans[];
      int orphanCount = g_stateRecovery.GetOrphanedPositions(orphans);
      
      for(int i = 0; i < orphanCount; i++)
      {
         Print("  Orphaned Ticket ", orphans[i].ticket, ": ", orphans[i].notes);
      }
   }
   
   Print("✓ State recovery completed");
   return recoverySuccess;
}

//================================================================================
// Setup Chart Objects (for visualization)
//================================================================================

void SetupChartObjects()
{
   // Optional: Add chart objects for key levels
   // This could include horizontal lines for support/resistance
   // Left blank for now - add as needed
}

//================================================================================
// OnTick - Main EA Logic
//================================================================================

void OnTick()
{
   if(!g_initialized)
      return;
   
   // Update account info (for changing balance/equity)
   g_riskManager.UpdateAccountInfo();
   
   // Check for new bars on all timeframes
   CheckNewBars();
   
   // Process updates on each timeframe when bar closes
   if(g_newBarStructure)
   {
      g_keyLevelStructure.Update();
      g_trendAnalysis.Update();
      g_patternStructure.DetectPatterns();
      
      if(InpPrintDebugInfo)
         PrintStructureTFDebug();
   }
   
   if(g_newBarConfirm)
   {
      g_keyLevelConfirm.Update();
      g_patternConfirm.DetectPatterns();
      
      if(InpPrintDebugInfo)
         PrintConfirmTFDebug();
   }
   
   if(g_newBarEntry)
   {
      g_keyLevelEntry.Update();
      g_momentumAnalysis.Update();
      
      // Execute entry logic on Entry TF bar close
      ProcessEntryLogic();
      
      if(InpPrintDebugInfo)
         PrintEntryTFDebug();
   }
   
   // Continuous monitoring (every tick)
   MonitorOpenPositions();
   
   // Check time-based filters
   CheckTimeBasedFilters();
}

//================================================================================
// Check for New Bars on Each Timeframe
//================================================================================

void CheckNewBars()
{
   // Structure Timeframe
   datetime timeStructure = iTime(Symbol(), InpStructureTimeframe, 0);
   if(timeStructure != g_lastBarStructure)
   {
      g_newBarStructure = true;
      g_lastBarStructure = timeStructure;
      g_tradesThisBar = 0;
   }
   else
   {
      g_newBarStructure = false;
   }
   
   // Confirmation Timeframe
   datetime timeConfirm = iTime(Symbol(), InpConfirmTimeframe, 0);
   if(timeConfirm != g_lastBarConfirm)
   {
      g_newBarConfirm = true;
      g_lastBarConfirm = timeConfirm;
   }
   else
   {
      g_newBarConfirm = false;
   }
   
   // Entry Timeframe
   datetime timeEntry = iTime(Symbol(), InpEntryTimeframe, 0);
   if(timeEntry != g_lastBarEntry)
   {
      g_newBarEntry = true;
      g_lastBarEntry = timeEntry;
   }
   else
   {
      g_newBarEntry = false;
   }
}

//================================================================================
// Process Entry Logic (Main Trading Strategy)
//================================================================================

void ProcessEntryLogic()
{
   // Prevent multiple entries on same bar
   if(g_tradesThisBar > 0)
      return;
   
   // Can only trade if we have less than max positions
   if(!g_tradeExecutor.CanAddPosition())
      return;
   
   // Get market context
   ENUM_TREND_BIAS structBias = g_trendAnalysis.GetStructureBias();
   ENUM_TREND_BIAS confirmBias = g_trendAnalysis.GetConfirmBias();
   ENUM_TREND_BIAS entryBias = g_trendAnalysis.GetEntryBias();
   
   double demandLevel = 0;
   double supplyLevel = 0;
   g_keyLevelEntry.GetDemandLevel(demandLevel);
   g_keyLevelEntry.GetSupplyLevel(supplyLevel);
   
   double currentPrice = Close[0];
   
   // ========== BUY SIGNAL LOGIC ==========
   if(structBias == BIAS_BULLISH && confirmBias == BIAS_BULLISH)
   {
      // HTF alignment is bullish
      
      // Check for CHOCH bullish (break above resistance)
      if(g_momentumAnalysis.DetectCHOCHBullish())
      {
         // Validate momentum at key level
         bool momentumValid = true;
         
         if(InpUseMomentumFilter)
         {
            // Check if price is at demand level with momentum loss first
            if(demandLevel > 0)
            {
               momentumValid = g_momentumAnalysis.IsMomentumLossNearLevel(demandLevel, 30);
            }
         }
         
         if(momentumValid)
         {
            // Get last higher low as breakout reference
            double lastHigherLow = g_momentumAnalysis.GetLastHigherLow();
            double stopLoss = g_keyLevelEntry.GetLastSwingLow();
            
            if(stopLoss > 0)
            {
               // Calculate SL below last swing low with buffer
               double finalSL = g_riskManager.CalculateStopLoss(true, stopLoss);
               
               // Get next supply level for TP target
               double nextSupply = 0;
               g_keyLevelStructure.GetSupplyLevel(nextSupply);
               
               // Calculate TP and lot size
               double entryPrice = currentPrice;
               double takeProfit = g_riskManager.CalculateTakeProfit(true, entryPrice, finalSL, nextSupply);
               double lotSize = g_riskManager.CalculateLotSize(entryPrice, finalSL);
               
               // Validate R:R ratio
               if(g_riskManager.ValidateRiskRewardRatio(entryPrice, finalSL, takeProfit))
               {
                  // Execute BUY entry
                  ulong ticket = g_tradeExecutor.ExecuteBuyEntry(entryPrice, finalSL, takeProfit, lotSize, "CHOCH Bullish");
                  
                  if(ticket > 0)
                  {
                     g_tradesThisBar++;
                     
                     if(InpPrintDebugInfo)
                     {
                        Print("BUY ENTRY EXECUTED!");
                        Print("  Ticket: ", ticket);
                        Print("  Entry: ", entryPrice);
                        Print("  SL: ", finalSL);
                        Print("  TP: ", takeProfit);
                        Print("  Lot: ", lotSize);
                     }
                  }
               }
            }
         }
      }
   }
   
   // ========== SELL SIGNAL LOGIC ==========
   if(structBias == BIAS_BEARISH && confirmBias == BIAS_BEARISH)
   {
      // HTF alignment is bearish
      
      // Check for CHOCH bearish (break below support)
      if(g_momentumAnalysis.DetectCHOCHBearish())
      {
         // Validate momentum at key level
         bool momentumValid = true;
         
         if(InpUseMomentumFilter)
         {
            // Check if price is at supply level with momentum loss first
            if(supplyLevel > 0)
            {
               momentumValid = g_momentumAnalysis.IsMomentumLossNearLevel(supplyLevel, 30);
            }
         }
         
         if(momentumValid)
         {
            // Get last lower high as breakout reference
            double lastLowerHigh = g_momentumAnalysis.GetLastLowerHigh();
            double stopLoss = g_keyLevelEntry.GetLastSwingHigh();
            
            if(stopLoss > 0)
            {
               // Calculate SL above last swing high with buffer
               double finalSL = g_riskManager.CalculateStopLoss(false, stopLoss);
               
               // Get next demand level for TP target
               double nextDemand = 0;
               g_keyLevelStructure.GetDemandLevel(nextDemand);
               
               // Calculate TP and lot size
               double entryPrice = currentPrice;
               double takeProfit = g_riskManager.CalculateTakeProfit(false, entryPrice, finalSL, nextDemand);
               double lotSize = g_riskManager.CalculateLotSize(entryPrice, finalSL);
               
               // Validate R:R ratio
               if(g_riskManager.ValidateRiskRewardRatio(entryPrice, finalSL, takeProfit))
               {
                  // Execute SELL entry
                  ulong ticket = g_tradeExecutor.ExecuteSellEntry(entryPrice, finalSL, takeProfit, lotSize, "CHOCH Bearish");
                  
                  if(ticket > 0)
                  {
                     g_tradesThisBar++;
                     
                     if(InpPrintDebugInfo)
                     {
                        Print("SELL ENTRY EXECUTED!");
                        Print("  Ticket: ", ticket);
                        Print("  Entry: ", entryPrice);
                        Print("  SL: ", finalSL);
                        Print("  TP: ", takeProfit);
                        Print("  Lot: ", lotSize);
                     }
                  }
               }
            }
         }
      }
   }
}

//================================================================================
// Monitor Open Positions
//================================================================================

void MonitorOpenPositions()
{
   g_tradeExecutor.UpdatePositionStates();
   
   int totalPos = g_tradeExecutor.GetTotalOpenPositions();
   
   if(totalPos == 0)
      return;
   
   // Check each position for TP/SL hit (shouldn't happen but monitor anyway)
   STRUCT_POSITION_STATE positions[];
   g_tradeExecutor.GetAllPositions(positions);
   
   for(int i = 0; i < totalPos; i++)
   {
      ulong ticket = positions[i].ticket;
      
      // Optional: Trail stop loss for winning positions
      if(positions[i].riskAmount > 0 && positions[i].rewardAmount > 0)
      {
         // Implement trailing stop or breakeven logic if desired
      }
   }
}

//================================================================================
// Check Time-Based Filters
//================================================================================

void CheckTimeBasedFilters()
{
   if(!InpUseTimeFilter)
      return;
   
   // Check if current time is outside trading hours
   MqlDateTime timeStruct;
   TimeToStruct(TimeCurrent(), timeStruct);
   
   int currentHour = timeStruct.hour;
   int currentMinute = timeStruct.min;
   
   int startTime = InpStartHour * 100 + InpStartMinute;
   int endTime = InpEndHour * 100 + InpEndMinute;
   int currentTime = currentHour * 100 + currentMinute;
   
   bool insideWindow = (currentTime >= startTime && currentTime < endTime);
   
   if(!insideWindow)
   {
      // Outside trading hours - close all positions if configured
      if(InpUseFridayClose)
      {
         // Check if it's Friday
         if(timeStruct.day_of_week == 5)  // Friday = 5
         {
            // Close all positions on Friday before market close
            g_tradeExecutor.CloseAllPositions();
         }
      }
   }
}

//================================================================================
// Debug Output Functions
//================================================================================

void PrintStructureTFDebug()
{
   if(!InpPrintDebugInfo)
      return;
   
   Print("--- STRUCTURE TF (", InpStructureTimeframe, ") DEBUG ---");
   
   ENUM_TREND_BIAS bias = g_trendAnalysis.GetStructureBias();
   Print("  Bias: ", (bias == BIAS_BULLISH ? "BULLISH" : bias == BIAS_BEARISH ? "BEARISH" : "NEUTRAL"));
   
   double supply = 0, demand = 0;
   g_keyLevelStructure.GetSupplyLevel(supply);
   g_keyLevelStructure.GetDemandLevel(demand);
   
   if(supply > 0)
      Print("  Supply Level: ", DoubleToString(supply, 5));
   if(demand > 0)
      Print("  Demand Level: ", DoubleToString(demand, 5));
}

void PrintConfirmTFDebug()
{
   if(!InpPrintDebugInfo)
      return;
   
   Print("--- CONFIRM TF (", InpConfirmTimeframe, ") DEBUG ---");
   
   ENUM_TREND_BIAS bias = g_trendAnalysis.GetConfirmBias();
   Print("  Bias: ", (bias == BIAS_BULLISH ? "BULLISH" : bias == BIAS_BEARISH ? "BEARISH" : "NEUTRAL"));
}

void PrintEntryTFDebug()
{
   if(!InpPrintDebugInfo)
      return;
   
   Print("--- ENTRY TF (", InpEntryTimeframe, ") DEBUG ---");
   
   ENUM_TREND_BIAS bias = g_trendAnalysis.GetEntryBias();
   Print("  Bias: ", (bias == BIAS_BULLISH ? "BULLISH" : bias == BIAS_BEARISH ? "BEARISH" : "NEUTRAL"));
   
   bool chochBull = g_momentumAnalysis.DetectCHOCHBullish();
   bool chochBear = g_momentumAnalysis.DetectCHOCHBearish();
   
   if(chochBull)
      Print("  CHOCH: BULLISH");
   if(chochBear)
      Print("  CHOCH: BEARISH");
   
   int totalPos = g_tradeExecutor.GetTotalOpenPositions();
   Print("  Open Positions: ", totalPos);
}

//================================================================================
// OnDeinit - EA Cleanup
//================================================================================

void OnDeinit(const int reason)
{
   Print("=== GoldMTFStructureEA - SHUTTING DOWN ===");
   Print("Shutdown Reason: ", GetDeinitReasonText(reason));
   
   // Save any state if needed
   // (Position data is already in broker, so no persistence needed)
   
   // Clean up memory
   if(g_keyLevelStructure != NULL)
      delete g_keyLevelStructure;
   
   if(g_keyLevelConfirm != NULL)
      delete g_keyLevelConfirm;
   
   if(g_keyLevelEntry != NULL)
      delete g_keyLevelEntry;
   
   if(g_trendAnalysis != NULL)
      delete g_trendAnalysis;
   
   if(g_patternStructure != NULL)
      delete g_patternStructure;
   
   if(g_patternConfirm != NULL)
      delete g_patternConfirm;
   
   if(g_momentumAnalysis != NULL)
      delete g_momentumAnalysis;
   
   if(g_riskManager != NULL)
      delete g_riskManager;
   
   if(g_tradeExecutor != NULL)
      delete g_tradeExecutor;
   
   if(g_stateRecovery != NULL)
      delete g_stateRecovery;
   
   Print("✓ All resources cleaned up");
   Print("=== EA SHUTDOWN COMPLETE ===");
}

//================================================================================
// Helper: Get Deinit Reason Text
//================================================================================

string GetDeinitReasonText(int reason)
{
   switch(reason)
   {
      case REASON_ACCOUNT:       return "Account was changed";
      case REASON_CHARTCHANGE:   return "Chart timeframe was changed";
      case REASON_CHARTCLOSE:    return "Chart was closed";
      case REASON_PARAMETERS:    return "Input parameters were changed";
      case REASON_RECOMPILE:     return "Program was recompiled";
      case REASON_REMOVE:        return "EA was removed from chart";
      case REASON_TEMPLATE:      return "Template was changed";
      case REASON_INITFAILED:    return "OnInit() returned error";
      case REASON_CLOSE:         return "Terminal is closing";
      default:                   return "Unknown reason";
   }
}

//================================================================================
// END OF EA
//================================================================================
