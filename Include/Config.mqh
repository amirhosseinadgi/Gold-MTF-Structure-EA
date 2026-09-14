//================================================================================
// Gold MTF Key-Level & Structure Breakout EA
// Config.mqh - Input Parameters & Data Structures
// Purpose: Centralized configuration and struct definitions
//================================================================================

#ifndef __CONFIG_MQH__
#define __CONFIG_MQH__

//================================================================================
// ENUMS & CONSTANTS
//================================================================================

enum ENUM_RISK_MODE
{
   RISK_PERCENT = 0,          // Risk as percentage of balance
   RISK_FIXED_MONEY = 1       // Risk as fixed USD amount
};

enum ENUM_PATTERN_TYPE
{
   PATTERN_NONE = 0,
   PATTERN_M_TOP = 1,
   PATTERN_W_BOTTOM = 2,
   PATTERN_HEAD_SHOULDERS = 3,
   PATTERN_UNTESTED_LEVEL = 4
};

enum ENUM_TREND_BIAS
{
   BIAS_NEUTRAL = 0,
   BIAS_BULLISH = 1,
   BIAS_BEARISH = -1
};

enum ENUM_SIGNAL_TYPE
{
   SIGNAL_NONE = 0,
   SIGNAL_BUY = 1,
   SIGNAL_SELL = -1
};

enum ENUM_POSITION_TYPE
{
   POS_LONG = OP_BUY,
   POS_SHORT = OP_SELL,
   POS_FLAT = -1
};

//================================================================================
// INPUT PARAMETERS - STRATEGY TIMEFRAMES
//================================================================================

input ENUM_TIMEFRAMES InpStructureTimeframe = PERIOD_D1;      // Structure Timeframe (HTF)
input ENUM_TIMEFRAMES InpConfirmTimeframe = PERIOD_H4;        // Confirmation Timeframe
input ENUM_TIMEFRAMES InpEntryTimeframe = PERIOD_H1;          // Entry Timeframe

//================================================================================
// INPUT PARAMETERS - KEY LEVEL DETECTION
//================================================================================

input int InpSwingLookback = 5;         // Bars left/right for Swing identification
input int InpMinLevelDistance = 50;     // Minimum pips between key levels
input bool InpUsePatternRecognition = true; // Enable M-top/W-bottom detection

//================================================================================
// INPUT PARAMETERS - ENTRY LOGIC
//================================================================================

input bool InpUseMomentumFilter = true; // Check for loss of momentum at key levels
input double InpMinBodyPercent = 0.4;   // Min body size % for momentum confirmation (0-1)
input bool InpUseChochOnly = true;      // Strict CLOSE-based CHOCH confirmation

//================================================================================
// INPUT PARAMETERS - RISK & MONEY MANAGEMENT
//================================================================================

input ENUM_RISK_MODE InpRiskMode = RISK_PERCENT;              // Risk calculation mode
input double InpRiskValue = 1.0;        // Risk: % of balance or USD amount
input int InpMaxOpenPositions = 2;      // Max concurrent positions (1-3)
input double InpMinRiskReward = 2.0;    // Minimum R:R ratio (e.g., 1:2)
input int InpSLBufferPoints = 10;       // Additional buffer beyond swing invalidation

//================================================================================
// INPUT PARAMETERS - SPREAD & EXECUTION FILTERS
//================================================================================

input int InpMaxSpreadPoints = 50;      // Max spread filter in points
input int InpSlippagePoints = 5;        // Max acceptable slippage in points

//================================================================================
// INPUT PARAMETERS - TIME FILTERS
//================================================================================

input bool InpUseTimeFilter = false;    // Enable time-of-day filter
input int InpStartHour = 0;             // Filter start hour (0-23)
input int InpStartMinute = 0;           // Filter start minute (0-59)
input int InpEndHour = 23;              // Filter end hour (0-23)
input int InpEndMinute = 59;            // Filter end minute (0-59)
input bool InpUseFridayClose = true;    // Close all positions before Friday close

//================================================================================
// INPUT PARAMETERS - EA MANAGEMENT
//================================================================================

input ulong InpMagicNumber = 20240914;  // Magic number for this EA
input string InpEAComment = "Gold-MTF-EA"; // Order comment
input bool InpPrintDebugInfo = true;    // Print detailed debug information

//================================================================================
// STRUCTURES - KEY LEVEL
//================================================================================

struct STRUCT_KEY_LEVEL
{
   double price;                        // Key level price
   ENUM_TREND_BIAS bias;                // Demand (bullish) or Supply (bearish)
   int timeframeShift;                  // Bars back when level formed
   ENUM_PATTERN_TYPE pattern;           // Associated pattern
   bool isTested;                       // Level has been retested
   bool isValid;                        // Level is currently valid
   datetime timeCreated;                // When level was identified
};

//================================================================================
// STRUCTURES - SWING POINT
//================================================================================

struct STRUCT_SWING_POINT
{
   double price;                        // Swing high or low price
   int barIndex;                        // Bar index where swing occurred
   bool isHigh;                         // True = swing high, False = swing low
   datetime timeStamp;                  // Time of swing formation
   int strength;                        // Strength rating (1-5)
};

//================================================================================
// STRUCTURES - ENTRY SIGNAL
//================================================================================

struct STRUCT_ENTRY_SIGNAL
{
   ENUM_SIGNAL_TYPE signal;             // BUY, SELL, or NONE
   ENUM_TREND_BIAS bias;                // Market bias at signal time
   double entryPrice;                   // Recommended entry price
   double stopLoss;                     // Stop loss price
   double takeProfit;                   // Take profit price
   double riskReward;                   // Actual R:R ratio
   datetime signalTime;                 // Time signal generated
   string reason;                       // Why signal was triggered
};

//================================================================================
// STRUCTURES - POSITION STATE
//================================================================================

struct STRUCT_POSITION_STATE
{
   ulong ticket;                        // Order ticket
   ENUM_POSITION_TYPE posType;          // LONG or SHORT
   double entryPrice;                   // Entry price
   double currentPrice;                 // Current close price
   double stopLoss;                     // Current stop loss
   double takeProfit;                   // Current take profit
   double riskAmount;                   // Risk in USD
   double rewardAmount;                 // Potential reward in USD
   int barsOpen;                        // Bars since entry
   datetime entryTime;                  // Entry timestamp
   bool isRescaled;                     // Position has been re-entered
};

//================================================================================
// STRUCTURES - MOMENTUM DATA
//================================================================================

struct STRUCT_MOMENTUM_DATA
{
   double bodySize;                     // Current candle body size (pips)
   double bodyPercent;                  // Body as % of high-low range
   bool isPinbar;                       // Is current candle a pinbar?
   double rejectionShadow;              // Wick size at key level (pips)
   bool isRejection;                    // Shows rejection pattern?
   int shrinkingBars;                   // Consecutive bars with shrinking bodies
};

//================================================================================
// STRUCTURES - MARKET CONTEXT
//================================================================================

struct STRUCT_MARKET_CONTEXT
{
   ENUM_TREND_BIAS structureBias;       // Structure TF bias
   ENUM_TREND_BIAS confirmBias;         // Confirm TF bias
   double latestSupplyLevel;            // Nearest supply level
   double latestDemandLevel;            // Nearest demand level
   bool isNearKeyLevel;                 // Price near any key level?
   double distToKeyLevel;               // Distance to nearest level (pips)
   int spreadPoints;                    // Current spread
   bool isMarketOpen;                   // Within trading hours?
};

//================================================================================
// LOGGING CONSTANTS
//================================================================================

#define LOG_LEVEL_ERROR   0
#define LOG_LEVEL_WARNING 1
#define LOG_LEVEL_INFO    2
#define LOG_LEVEL_DEBUG   3

//================================================================================
#endif // __CONFIG_MQH__
//================================================================================
