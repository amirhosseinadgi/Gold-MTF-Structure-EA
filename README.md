# Gold MTF Key-Level & Structure Breakout EA

**A Professional Multi-Timeframe Expert Advisor for Trading Gold (XAUUSD) Using Key Levels, Chart Patterns, and Momentum Analysis**

---

## 📋 Table of Contents

- [Strategy Overview](#strategy-overview)
- [Key Features](#key-features)
- [Architecture & File Breakdown](#architecture--file-breakdown)
- [Module Descriptions](#module-descriptions)
- [Input Parameters](#input-parameters)
- [Installation & Setup](#installation--setup)
- [Backtesting Instructions](#backtesting-instructions)
- [Live Trading Checklist](#live-trading-checklist)
- [Troubleshooting](#troubleshooting)
- [Performance Tips](#performance-tips)
- [License](#license)

---

## 🎯 Strategy Overview

### Multi-Timeframe Structure

This EA uses a **3-timeframe hierarchy** for robust trading decisions:

1. **Structure Timeframe (Daily - D1)**
   - Identifies the long-term trend and major support/resistance levels
   - Trend bias must align bullish or bearish for entry signals
   - Highest timeframe context for market direction

2. **Confirmation Timeframe (4-Hour - H4)**
   - Validates the Structure TF bias
   - Provides secondary confirmation for trend alignment
   - Detects intermediate patterns (M-top, W-bottom, H&S)

3. **Entry Timeframe (1-Hour - H1)**
   - Executes CHOCH (Change of Character) breakout signals
   - Detects loss of momentum with pinbars and shrinking bodies
   - Precise entry point with tight stop loss

### Trading Logic Flow

```
┌─────────────────────────────────────────────────────┐
│ 1. MULTI-TIMEFRAME ALIGNMENT                        │
│    Struct(D1) + Confirm(H4) both BULLISH/BEARISH?   │
│    ✓ YES → Continue                                 │
│    ✗ NO → Skip signals                              │
└─────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│ 2. KEY LEVEL IDENTIFICATION                         │
│    Find last swing highs/lows on Entry TF (H1)      │
│    Identify support (demand) & resistance (supply)  │
│    Mark invalidation levels for stop loss           │
└─────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│ 3. MOMENTUM VALIDATION (Optional Filter)            │
│    Check for shrinking candle bodies                │
│    Detect pinbars/rejection at key levels           │
│    Validate loss of momentum before breakout        │
└─────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│ 4. CHOCH SIGNAL DETECTION                           │
│    Bullish: Close breaks above last Lower High      │
│    Bearish: Close breaks below last Higher Low      │
│    Strong body (≥50% of range) required             │
└─────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│ 5. RISK-REWARD VALIDATION                           │
│    Calculate lot size based on risk mode            │
│    Set SL at invalidation level (+ buffer)          │
│    Set TP at next key level (or R:R multiple)       │
│    Minimum R:R = 1:2 (configurable)                 │
│    Validate broker spread & margin                  │
└─────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│ 6. TRADE EXECUTION                                  │
│    Place market order with SL & TP                  │
│    Log trade to position tracker                    │
│    Enable position scaling (up to 3 total)          │
│    Auto-recovery on EA restart                      │
└─────────────────────────────────────────────────────┘
```

### Example Trade Scenario (BULLISH)

```
DAILY (D1):        Higher Highs & Higher Lows → BULLISH Bias
4-HOUR (H4):       Close above 50 EMA → BULLISH Confirmation
1-HOUR (H1):
  
  2000.00 ──────────────── Supply Level (Resistance)
           Last Lower High  ← CHOCH breakout target
  1950.00 ─┐
           │ Entry Zone (Shrinking bodies + pinbar)
  1940.00 ─┘ Last swing low (invalidation)
           
  Signal:
  - Price approaches 1950 with momentum loss
  - Next H1 candle closes ABOVE 1950
  - Body is strong (≥50% of range)
  
  Trade Setup:
  - Entry: 1950.50
  - Stop Loss: 1940.00 - 10 pips buffer = 1939.90
  - Take Profit: 2000.00 (next supply level)
  - Lot Size: Calculated for 1% account risk
  - R:R Ratio: (1950.50 - 1939.90) / (2000 - 1950.50) ≈ 1:2.0 ✓
```

---

## ✨ Key Features

### 1. **Multi-Timeframe Key Level Detection**
- Automatic identification of swing highs and lows
- Dynamic support (demand) and resistance (supply) levels
- Adjustable lookback period for swing identification
- Minimum distance filter to avoid level clustering

### 2. **CHOCH Breakout Detection**
- Change of Character (CHOCH) / Break of Structure (BOS)
- Tracks higher highs/lows (uptrend) and lower highs/lows (downtrend)
- Close-based confirmation (no wick false breaks)
- Validates momentum with minimum body size

### 3. **Loss of Momentum Filter**
- Detects shrinking candle bodies (consecutive decreasing size)
- Pinbar and rejection shadow identification
- Validates momentum loss before CHOCH breakout
- Optional filter (can be disabled for more signals)

### 4. **Pattern Recognition**
- M-Top pattern detection (bearish reversal)
- W-Bottom pattern detection (bullish reversal)
- Head & Shoulders pattern detection
- Neckline break validation for pattern confirmation

### 5. **Dynamic Position Sizing**
- Two risk modes:
  - **Percent Mode:** Risk X% of account balance
  - **Fixed Money Mode:** Risk fixed USD amount per trade
- Automatic lot size calculation based on SL distance
- Broker requirement compliance (min/max lot, lot step)
- Free margin validation

### 6. **Strict Risk-to-Reward Validation**
- Minimum R:R ratio enforcement (default 1:2)
- Actual R:R calculation before trade execution
- Trade rejection if R:R below threshold
- Broker spread and StopsLevel compliance checks

### 7. **Position Scaling (Re-entries)**
- Support for up to 3 concurrent positions
- Scaling in on retest of newly formed untested levels
- Individual position tracking by ticket
- Partial close capability for profit taking

### 8. **Full Crash Recovery**
- Automatic state restoration on EA restart
- Scans broker for positions with matching Magic Number
- Detects and flags orphaned positions
- Zero position loss on MT5 crash or disconnect
- Orphaned position detection and reporting

### 9. **Broker Compliance**
- StopsLevel validation (minimum SL distance)
- Spread limit enforcement
- Freeze level respect
- Free margin availability checks
- Automatic retry logic for failed orders

### 10. **Debug & Monitoring**
- Optional debug output for all timeframes
- Position status tracking
- Trade signal logging (with reasons)
- Recovery report on EA startup
- Comprehensive error handling

---

## 🏗️ Architecture & File Breakdown

```
Gold-MTF-Structure-EA/
│
├── Experts/
│   └── GoldMTFStructureEA.mq5              Main EA (23.6 KB)
│                                           Entry point, orchestrator
│
├── Include/
│   ├── Config.mqh                          (9.3 KB)
│   │   └─ Input parameters & data structures
│   │
│   ├── KeyLevelDetection.mqh               (14.9 KB)
│   │   └─ Swing level identification, support/resistance
│   │
│   ├── TrendBiasAnalysis.mqh               (13.0 KB)
│   │   └─ Multi-timeframe trend assessment (D1/H4/H1)
│   │
│   ├── PatternRecognition.mqh              (16.6 KB)
│   │   └─ M-top, W-bottom, Head & Shoulders detection
│   │
│   ├── MomentumAnalysis.mqh                (17.6 KB)
│   │   └─ Loss of momentum, CHOCH/BOS signals
│   │
│   ├── RiskManagement.mqh                  (19.7 KB)
│   │   └─ Position sizing, SL/TP calculation, R:R validation
│   │
│   ├── TradeExecution.mqh                  (25.1 KB)
│   │   └─ Order placement, position management, scaling
│   │
│   └── StateRecovery.mqh                   (22.3 KB)
│       └─ Crash recovery, state synchronization
│
└── README.md                                (This file)
    └─ Complete documentation & setup guide
```

**Total Code Size: ~161 KB of professional MQL5**

---

## 📚 Module Descriptions

### 1. Config.mqh - Configuration & Data Structures
**Purpose:** Central configuration, input parameters, and custom data structures

**Key Components:**
- Input parameter declarations (20+ tunable parameters)
- Enum definitions: Risk modes, trend biases, patterns
- Custom structs for position tracking and recovery data
- Log level constants for debug output

**Used By:** All other modules inherit input parameters

---

### 2. KeyLevelDetection.mqh - Swing & Level Identification
**Purpose:** Identify support/resistance levels from swing highs and lows

**Core Functions:**
- `Update()` - Scan for new swing formations
- `GetSupplyLevel()` - Get resistance level
- `GetDemandLevel()` - Get support level
- `GetLastSwingHigh()` / `GetLastSwingLow()` - Latest extremes
- `ValidateLevel()` - Check if level is valid

**Algorithm:**
1. Scan last N bars for local highs and lows
2. Identify swing points (higher/lower than neighbors)
3. Filter by minimum distance to avoid clustering
4. Return most recent support and resistance

**Used By:** TradeExecution (for SL placement), RiskManagement (for TP targets)

---

### 3. TrendBiasAnalysis.mqh - Multi-Timeframe Trend Assessment
**Purpose:** Determine market bias across 3 timeframes (D1, H4, H1)

**Core Functions:**
- `Update()` - Update trend on each timeframe
- `GetOverallBias()` - Combined alignment (BULLISH/BEARISH/NEUTRAL)
- `IsFullyAligned()` - All TFs point same direction?
- `GetTrendStrength()` - Strength indicator (0-3)
- `GetStructureBias()`, `GetConfirmBias()`, `GetEntryBias()`

**Algorithm:**
- Uses EMA 20/50 crossovers for initial bias
- Validates with higher high/low pattern
- Requires candle body confirmation
- Tracks momentum in pips

**Used By:** Main EA (filters entry signals)

---

### 4. PatternRecognition.mqh - Chart Pattern Detection
**Purpose:** Identify reversal patterns (M-Top, W-Bottom, Head & Shoulders)

**Core Functions:**
- `DetectPatterns()` - Main detection function
- `DetectMTop()` - Bearish reversal
- `DetectWBottom()` - Bullish reversal
- `DetectHeadAndShoulders()` - Reversal
- `IsNecklineBroken()` - CLOSE-BASED confirmation
- `CalculatePatternTarget()` - Calculate profit target

**Validation Criteria:**
- Peak/trough structure (similar heights/depths)
- Neckline close-based breaks (no wick false breaks)
- Recent pattern formation (within 20 bars)
- Distance from current price (within 100 pips)

**Used By:** Optional pattern confirmation (can enhance signals)

---

### 5. MomentumAnalysis.mqh - Loss of Momentum & CHOCH Detection
**Purpose:** Detect momentum loss and CHOCH breakout signals

**Core Functions:**
- `DetectMomentumLoss()` - Shrinking bodies + rejections
- `DetectCHOCHBullish()` - Break above resistance
- `DetectCHOCHBearish()` - Break below support
- `IsMomentumLossNearLevel()` - Momentum loss at key level
- `GetMomentumScore()` - Quality 0-10 rating
- `CountShrinkingBars()` - Consecutive small bodies

**Momentum Loss Indicators:**
1. Consecutive shrinking candle bodies (≥2 bars)
2. Pinbar with wick >2x body size
3. Rejection shadow >2x body size
4. Body <40% of range + large shadow

**CHOCH Validation:**
- Close breaks structure swing
- Strong body (≥50% of range)
- Recent swing formation (<5 bars)
- No rejection wicks on entry candle

**Used By:** Main EA (primary entry signal)

---

### 6. RiskManagement.mqh - Position Sizing & R:R Validation
**Purpose:** Calculate lot sizes and validate risk-reward ratios

**Core Functions:**
- `CalculateRiskAmount()` - Risk in USD
- `CalculateLotSize(entry, SL)` - Dynamic sizing
- `CalculateStopLoss(isBuy, level)` - SL calculation
- `CalculateTakeProfit(isBuy, entry, SL, keyLevel)` - TP calculation
- `ValidateRiskRewardRatio(entry, SL, TP)` - R:R check
- `ValidateCompleteTradeSetup()` - All-in-one validation

**Position Sizing Formula:**
```
Risk Amount = Balance × (RiskPercent / 100)  [PERCENT MODE]
Risk Amount = FixedUSD                        [FIXED MODE]

Lot Size = Risk Amount / (SL Distance in pips × Tick Value)
Normalized Lot = Round to broker's lot step
Clamped Lot = Clamp between min/max lot sizes
```

**R:R Validation:**
```
Risk = |Entry - SL|
Reward = |TP - Entry|
Ratio = Reward / Risk

✓ VALID if: Ratio >= Minimum R:R (e.g., 1:2)
✗ REJECTED if: Ratio < Minimum R:R
```

**Compliance Checks:**
- Broker StopsLevel (min SL distance)
- Spread limit enforcement
- Free margin availability
- Freeze level respect

**Used By:** Main EA (before trade execution)

---

### 7. TradeExecution.mqh - Order Placement & Position Management
**Purpose:** Execute trades, modify positions, manage scaling

**Core Functions:**
- `ExecuteBuyEntry()` / `ExecuteSellEntry()` - Market entry
- `ModifyPosition()` / `ModifyStopLoss()` / `ModifyTakeProfit()` - Modify
- `ClosePosition()` / `PartialClose()` / `CloseAllPositions()` - Close
- `CanAddPosition()` - Scaling check
- `IsValidReentryLevel()` - Retest validation
- `AttemptScalingEntry()` - Scale-in execution
- `TrailStopLoss()` / `MoveToBreakeven()` - SL management

**Order Execution:**
- Uses TRADE_ACTION_BUY / TRADE_ACTION_SELL
- ORDER_FILLING_IOC (Fill or Kill - prevents partial fills)
- Automatic retry logic (3 attempts, 500ms delay)
- Magic number attached to all orders

**Position Limits:**
- Max 3 concurrent positions (configurable 1-3)
- One trade per bar (prevents multi-entry on same bar)
- Strict Magic Number filtering (multi-EA safe)

**Scaling Logic:**
- Check if position exists in same direction
- Validate position count < max
- Confirm price retesting untested level
- Execute new entry with validated SL/TP

**Used By:** Main EA (executes signals)

---

### 8. StateRecovery.mqh - Crash Recovery & State Sync
**Purpose:** Restore EA state from broker positions on restart

**Core Functions:**
- `RecoverStateOnInit()` - Full 4-step recovery
- `RecoverActivePositions()` - Scan open positions
- `RecoverPendingOrders()` - Scan pending orders
- `FixMissingSLTP()` - Detect broken positions
- `DetectOrphanedPositions()` - Find anomalies
- `SynchronizeState()` - Continuous sync
- `ValidateAllPositionProtection()` - Check SL/TP exist

**Recovery Process:**
1. Scan broker for all open positions
2. Filter by Magic Number (our EA only)
3. Load positions into TradeExecution
4. Detect missing SL/TP and flag issues
5. Identify orphaned positions
6. Generate recovery summary report

**Orphan Detection:**
- Missing both SL and TP
- SL too far away (>500 pips)
- TP too far away (>1000 pips)
- Position opened >7 days ago without closure

**Used By:** Main EA OnInit() (startup recovery)

---

## ⚙️ Input Parameters

### Timeframe Configuration

```
Struct_Timeframe          = PERIOD_D1   (Daily)
  └─ Higher timeframe, sets trend direction
  └─ Recommended: D1 for Gold

Confirm_Timeframe         = PERIOD_H4   (4-Hour)
  └─ Medium timeframe, confirms trend
  └─ Recommended: H4 for Gold

Entry_Timeframe           = PERIOD_H1   (1-Hour)
  └─ Lower timeframe, executes entries
  └─ Recommended: H1 for Gold
```

**Why D1/H4/H1?**
- D1 captures major trend changes
- H4 provides confirmation without noise
- H1 allows precise entries without scalping
- Prevents whipsaw trades on smaller TFs

---

### Key Level Detection

```
Swing_Lookback            = 5 (Range: 3-10)
  └─ Number of bars left/right to identify swings
  └─ 5 = Conservative, finds major swings
  └─ 10 = Aggressive, finds more swings
  └─ Recommended for Gold: 5-7

Min_Level_Distance        = 50 (pips)
  └─ Minimum pips between support/resistance
  └─ Prevents level clustering
  └─ Recommended for Gold: 50-100

Use_Pattern_Recognition   = true
  └─ Enable M-top/W-bottom/H&S detection
  └─ Optional signal enhancement
  └─ Recommended: true
```

---

### Entry Logic

```
Use_Momentum_Filter       = true
  └─ Require momentum loss before CHOCH
  └─ Detects shrinking bodies + pinbars
  └─ Reduces false breakouts
  └─ Recommended: true for live trading

Min_Body_Percent          = 0.40 (40%)
  └─ Minimum body size for valid momentum
  └─ 0.40 = 40% of candle range must be body
  └─ Larger = stricter, fewer signals
  └─ Recommended: 0.30-0.50

Use_CHOCH_Only            = true
  └─ Only enter on CHOCH signals
  └─ Ignores pattern breakouts alone
  └─ More consistent entries
  └─ Recommended: true
```

---

### Risk Management

```
Risk_Mode                 = RISK_PERCENT
  └─ Options: RISK_PERCENT or RISK_FIXED_MONEY
  └─ PERCENT = Risk X% of balance per trade
  └─ FIXED_MONEY = Risk fixed USD per trade
  └─ Recommended for beginners: RISK_PERCENT

Risk_Value                = 1.0 (1% of balance)
  └─ For RISK_PERCENT: 1.0 = 1% account risk per trade
  └─ For RISK_FIXED_MONEY: 100 = $100 USD risk per trade
  └─ Recommended: 1-2% (conservative)
  └─ Aggressive: 3-5% (high risk)

Max_Open_Positions        = 2 (Range: 1-3)
  └─ Maximum concurrent positions
  └─ 1 = One trade at a time (conservative)
  └─ 2 = Two scales allowed (moderate)
  └─ 3 = Three scales allowed (aggressive)
  └─ Recommended: 2

Min_Risk_Reward           = 2.0 (1:2 ratio)
  └─ Minimum reward must be 2x risk
  └─ Example: Risk $100, must gain $200+ 
  └─ 1.5 = More trades (lower bar)
  └─ 3.0 = Fewer trades (higher standard)
  └─ Recommended: 2.0-2.5

SL_Buffer_Points          = 10 (pips)
  └─ Additional pips beyond invalidation level
  └─ Example: Swing low 1940, buffer 10 = SL 1939.90
  └─ Prevents SL hit on noise
  └─ Recommended: 5-15
```

---

### Execution Settings

```
Max_Spread_Points         = 50 (pips)
  └─ Only trade if spread <= this value
  └─ 50 pips = normal conditions for Gold
  └─ 100 pips = tight spreads only
  └─ Recommended: 50-75

Slippage_Points           = 5 (pips)
  └─ Max acceptable slippage on entry
  └─ Broker tolerance
  └─ Recommended: 5-10

Magic_Number              = 20240914
  └─ Unique identifier for your EA
  └─ Change if running multiple EAs
  └─ CRITICAL: Must be unique per EA instance

EA_Comment                = "Gold-MTF-EA"
  └─ Comment on orders (for identification)
  └─ Shows in trade history
```

---

### Time Filters

```
Use_Time_Filter           = false
  └─ Enable trading hours restriction
  └─ Disable signals outside window
  └─ Useful for news avoidance

Start_Hour                = 0
Start_Minute              = 0
  └─ Trading starts at this time (GMT)

End_Hour                  = 23
End_Minute                = 59
  └─ Trading ends at this time (GMT)

Use_Friday_Close          = true
  └─ Automatically close all positions Friday
  └─ Avoid weekend gap risk
  └─ Recommended: true
```

---

### Debug & Monitoring

```
Print_Debug_Info          = false
  └─ Print debug output to Journal (verbose)
  └─ Used for testing/troubleshooting
  └─ Recommended: false (live) / true (testing)

Debug_Print_Level         = LOG_LEVEL_INFO
  └─ Level: LOG_LEVEL_DEBUG (most verbose) → LOG_LEVEL_ERROR
  └─ Controls output verbosity
```

---

## 📥 Installation & Setup

### Step 1: Download & Prepare

1. **Clone or download** this repository
   ```bash
   git clone https://github.com/amirhosseinadgi/Gold-MTF-Structure-EA.git
   ```

2. **Locate your MetaTrader 5 Data Folder**
   - Windows: `C:\Users\[YourUsername]\AppData\Roaming\MetaQuotes\Terminal\[TerminalID]\`
   - Or use: File → Open Data Folder (in MT5)

3. **Copy files to correct directories:**
   ```
   Copy:  Experts/GoldMTFStructureEA.mq5
   To:    [MT5 Data Folder]/MQL5/Experts/
   
   Copy:  Include/*.mqh (all 8 files)
   To:    [MT5 Data Folder]/MQL5/Include/
   ```

### Step 2: Compile the EA

1. Open **MetaTrader 5**
2. Go to **File → Open Data Folder**
3. Navigate to **MQL5/Experts**
4. Right-click **GoldMTFStructureEA.mq5**
5. Select **Edit** (or open with your MQL5 editor)
6. Press **Ctrl+F5** to compile
   - Watch for errors in the Errors panel
   - Should show: "Compilation successful"

**Common Compilation Errors:**
- **Error: Include file not found** → Check all .mqh files are in MQL5/Include/
- **Error: Undeclared identifier** → Ensure all includes are before usage
- **Warning: Unreferenced parameter** → Harmless warnings, can ignore

### Step 3: Configure Input Parameters

1. Open **MetaTrader 5**
2. Click **View → Toolbox** (if not open)
3. On your chart, attach **GoldMTFStructureEA**:
   - Insert → Advisors → GoldMTFStructureEA
4. Input Parameters tab will open

**Recommended Starting Configuration:**
```
Timeframe Configuration:
  Struct_Timeframe        = PERIOD_D1
  Confirm_Timeframe       = PERIOD_H4
  Entry_Timeframe         = PERIOD_H1

Key Level Detection:
  Swing_Lookback          = 5
  Min_Level_Distance      = 50
  Use_Pattern_Recognition = true

Entry Logic:
  Use_Momentum_Filter     = true
  Min_Body_Percent        = 0.40
  Use_CHOCH_Only          = true

Risk Management:
  Risk_Mode               = RISK_PERCENT
  Risk_Value              = 1.0
  Max_Open_Positions      = 2
  Min_Risk_Reward         = 2.0
  SL_Buffer_Points        = 10

Execution:
  Max_Spread_Points       = 50
  Slippage_Points         = 5
  Magic_Number            = 20240914
  EA_Comment              = "Gold-MTF-EA"

Time Filters:
  Use_Time_Filter         = false
  Use_Friday_Close        = true

Debug:
  Print_Debug_Info        = true  ← Set to TRUE for testing
```

### Step 4: Test on Demo Account

1. **Attach to XAUUSD chart:**
   - Open XAUUSD chart (H1 timeframe recommended)
   - Insert → Advisors → GoldMTFStructureEA
   - Click "Allow WebRequest" if prompted
   - Click OK

2. **Monitor startup:**
   - Watch **Journal tab** for initialization messages
   - Should see: "=== EA INITIALIZATION SUCCESSFUL ==="
   - Check for state recovery messages

3. **Observe signals:**
   - EA will wait for CHOCH on H1
   - Debug output will show:
     - Trend bias on each TF
     - CHOCH detection
     - Open positions

4. **Let it run 2-3 weeks** before adjusting parameters

---

## 🧪 Backtesting Instructions

### In MetaTrader 5

1. **Open Strategy Tester:**
   - View → Strategy Tester (or Ctrl+R)

2. **Configure Backtest:**
   - Expert Advisor: GoldMTFStructureEA
   - Symbol: XAUUSD
   - Period: H1
   - Model: "Every tick" (most accurate)
   - Date Range: 
     - From: 2023.01.01 (or earlier)
     - To: Today (or recent date)

3. **Set Parameters:**
   - Click "Inputs" tab
   - Use recommended config above
   - Test different combinations:
     - Risk: 0.5%, 1.0%, 2.0%
     - Swing_Lookback: 3, 5, 7
     - Min_Body_Percent: 0.30, 0.40, 0.50

4. **Run Backtest:**
   - Click "Start"
   - Wait for completion (30 min - 2 hours typical)
   - Watch progress bar

5. **Review Results:**
   - **Report tab:** Overall statistics
   - **Graph tab:** Equity curve
   - **Results tab:** Individual trades

**Key Metrics to Review:**
```
Total Trades              ← Should be 20-50 per month
Winning Trades %          ← Target: 50%+ win rate
Profit Factor             ← Target: 2.0+ (2x risk/reward)
Drawdown %                ← Should be <20% of balance
Recovery Factor           ← Higher is better
Sharpe Ratio              ← Higher is better (consistency)
```

**Example Good Results:**
```
Period Analyzed:          12 months
Total Trades:             180
Winning Trades:           100 (55.6%)
Losing Trades:            80 (44.4%)
Profit Factor:            2.35
Total Profit:             $45,000
Max Drawdown:             -$8,500 (18%)
Recovery Factor:          5.3
Sharpe Ratio:             1.85
```

### Parameter Optimization

1. Click **"Optimization"** button (before Start)
2. Select parameters to optimize:
   - Swing_Lookback: from 3 to 10, step 1
   - Min_Body_Percent: from 0.30 to 0.50, step 0.05
   - Risk_Value: from 0.5 to 3.0, step 0.5

3. Click **"Start Optimization"**
   - Runs all combinations
   - Takes 2-4 hours typically

4. **Review results:**
   - Sort by Profit Factor
   - Select top 5-10 results
   - Check for curve-fitting (overfitting)

**Warning: Avoid Overfitting**
- Best backtest results ≠ best live results
- Use conservative parameters
- Test on out-of-sample data (recent months)
- Focus on consistency, not maximum profit

---

## ✅ Live Trading Checklist

Before going live, verify:

- [ ] **Account Setup:**
  - [ ] Demo account ready (min $5,000 recommended)
  - [ ] All permissions enabled
  - [ ] Trading hours configured
  - [ ] Account currency verified

- [ ] **EA Configuration:**
  - [ ] All input parameters reviewed
  - [ ] Magic Number is unique
  - [ ] Risk mode matches strategy (% vs Fixed)
  - [ ] Risk amount is conservative (1% or less)
  - [ ] Timeframes: D1/H4/H1 confirmed

- [ ] **Broker Compatibility:**
  - [ ] Symbol XAUUSD available
  - [ ] Spreads normal (50 pips or less)
  - [ ] Leverage sufficient (max 50:1 tested)
  - [ ] StopsLevel acceptable (<20 pips)

- [ ] **Testing Complete:**
  - [ ] Backtest run (12+ months data)
  - [ ] Results reviewed (Profit Factor > 2.0)
  - [ ] Parameter optimization done
  - [ ] Out-of-sample test passed
  - [ ] 2 weeks demo trading completed

- [ ] **Monitoring Setup:**
  - [ ] Print_Debug_Info = true initially
  - [ ] Journal watched daily
  - [ ] Trades reviewed daily
  - [ ] Performance metrics tracked

- [ ] **Risk Control:**
  - [ ] Stop loss on every trade verified
  - [ ] Take profit points reasonable
  - [ ] No more than 3 positions per signal
  - [ ] Total account risk < 5% per trade
  - [ ] Daily loss limit set (stop EA if hit)

- [ ] **Contingency Plan:**
  - [ ] Know how to close all positions manually
  - [ ] Backup plan for broker connection loss
  - [ ] Recovery procedure practiced
  - [ ] Support contact info saved

**Go-Live Decision:**
- ✓ Live account only if ALL above checked
- ✓ Start with minimum lot size (0.01)
- ✓ Scale up after 2-4 weeks of profitable trading
- ✓ Never risk more than 1% per trade

---

## 🔧 Troubleshooting

### EA Not Starting

**Problem:** EA shows red "X" on chart (not running)

**Solutions:**
1. Check Journal tab:
   - View → Toolbox → Journal
   - Look for error messages
   
2. Common errors:
   - "Expert Advisor Error: No data" → Wait for price data to load
   - "Compilation failed" → Recompile (see Installation Step 2)
   - "Account not available" → Check broker connection

3. Allow DLL imports (if needed):
   - Tools → Options → Expert Advisors
   - Check "Allow live trading" and "Allow DLL imports"

---

### No Trades Generated

**Problem:** EA running but not entering trades

**Verification:**
1. Enable debug output:
   - Set `Print_Debug_Info = true`
   - Watch Journal for signal info

2. Check alignment:
   ```
   If Journal shows:
   "Bias: NEUTRAL" on D1/H4 → No trade (need alignment)
   "CHOCH: Neither" on H1 → Waiting for breakout
   ```

3. Common causes:
   - Market not in clear trend (neutral bias)
   - No CHOCH signal yet (price not at levels)
   - Momentum filter blocking (set `Use_Momentum_Filter = false` to test)
   - Spread too wide (check `Max_Spread_Points`)

4. Fix:
   - Adjust `Swing_Lookback` (try 3-10 range)
   - Reduce `Min_Level_Distance` (more levels detected)
   - Disable `Use_Momentum_Filter` temporarily

---

### Too Many Losing Trades

**Problem:** More losses than expected

**Analysis:**
1. Review backtest results:
   - Is win rate below 45%?
   - Is profit factor below 2.0?

2. Adjust parameters:
   - Increase `Swing_Lookback` (fewer, stronger levels)
   - Increase `Min_Body_Percent` (stricter momentum)
   - Increase `Min_Risk_Reward` (1:2 → 1:3)
   - Disable `Use_Pattern_Recognition` (focus on CHOCH)

3. Add filters:
   - Enable `Use_Time_Filter` (avoid news/volatility)
   - Enable `Use_Friday_Close` (avoid weekends)

4. Test new settings in backtest before going live

---

### Position Not Closing at TP/SL

**Problem:** Trade stays open past TP or SL

**Note:** This is normal sometimes
- EA relies on broker SL/TP execution
- May need 1-2 ticks to trigger
- Check position manually if unsure
- Never move SL closer to price (risky)

**Solution:**
- Add TrailStopLoss feature (in TradeExecution)
- Monitor large positions more closely
- Consider tighter SL/TP if consistent issue

---

### Magic Number Issues

**Problem:** Mixing up positions from multiple EAs

**Solution:**
1. Each EA instance MUST have unique Magic Number:
   - EA 1: Magic_Number = 20240914
   - EA 2: Magic_Number = 20240915
   - EA 3: Magic_Number = 20240916

2. Check positions:
   - Journal will show Magic Number when closing
   - Only your trades are modified/closed

3. If confused:
   - Use different accounts per EA
   - Or change Magic_Number before attaching

---

### Crash Recovery Not Working

**Problem:** Positions lost after EA restart

**Verification:**
1. Check Journal on restart:
   - Should show: "State Recovery Summary"
   - Should show: "Positions Recovered: X"

2. If recovery failed:
   - Positions likely already recovered by broker
   - Check open positions manually in Terminal
   - EA will pick them up on next tick

3. Orphaned position warning:
   - If detected, review position manually
   - Check SL/TP are present
   - Can close manually if needed

---

## 🚀 Performance Tips

### For Maximum Profitability

1. **Optimize for Win Rate First**
   - Focus on consistent winners
   - Adjust to 55%+ win rate
   - Then optimize profit factor

2. **Reduce Drawdown**
   - Lower risk per trade (0.5-1%)
   - Increase `Min_Risk_Reward` (1:2.5 or higher)
   - Use `SL_Buffer_Points` appropriately

3. **Quality over Quantity**
   - Fewer high-probability trades > many mediocre trades
   - Increase `Swing_Lookback` (fewer but stronger levels)
   - Enable `Use_Momentum_Filter` (filters false breaks)

4. **Diversify Timeframes** (Advanced)
   - Run separate EA instances on D1/H4 bias
   - Combine signals with automation
   - Use different Magic Numbers per timeframe

### For Stability & Reliability

1. **Conservative Parameters**
   - Risk: 1% per trade (not 2-3%)
   - Max positions: 2 (not 3)
   - Min R:R: 2.0 (not 1.5)

2. **Regular Monitoring**
   - Check trades daily
   - Review equity curve weekly
   - Optimize parameters monthly

3. **Broker Selection**
   - Low spreads (40-60 pips for Gold typical)
   - Fast execution (<500ms)
   - Good customer support

4. **Account Size**
   - Minimum $5,000 recommended (for 1% risk)
   - Larger = more comfortable
   - Can scale up after 3 months profitability

---

## 📞 Support & Resources

### Getting Help

1. **Check this README** - Most issues covered
2. **Review Journal output** - Debug messages guide troubleshooting
3. **Study the code** - Well-commented modules explain logic
4. **Backtest first** - Always test parameters before live

### Recommended Resources

- **MetaTrader 5 Documentation:** https://www.mql5.com/en/docs
- **MQL5 Community:** https://www.mql5.com/en/forum
- **Trading Resources:** https://www.babypips.com (Forex education)
- **Gold Trading:** https://www.investopedia.com (Gold fundamentals)

---

## 📄 License

This Expert Advisor is provided as-is for educational and personal use.

**Disclaimer:**
- Trading foreign exchange and derivatives carries significant risk
- Past performance does not guarantee future results
- Use demo account first before live trading
- Risk only capital you can afford to lose
- This EA is provided without warranty

---

## 🎉 Summary

**You now have:**

✅ Professional-grade Multi-Timeframe Gold EA  
✅ 8 modular components (161 KB of code)  
✅ Full crash recovery capability  
✅ Dynamic position sizing  
✅ CHOCH breakout detection  
✅ Momentum loss validation  
✅ Strict R:R validation  
✅ Broker compliance checks  
✅ Complete documentation  

**Next Steps:**
1. Download the repository
2. Install files to MT5 folder
3. Compile the EA
4. Configure parameters (use recommendations above)
5. Backtest on historical Gold data
6. Demo trade for 2-4 weeks
7. Go live with proper risk management

---

**Created:** 2026-09-14  
**Version:** 1.00  
**Author:** Gold MTF Structure EA Project  
**Repository:** https://github.com/amirhosseinadgi/Gold-MTF-Structure-EA

---

**Questions? Issues? Improvements?** Open an issue or contribute to this repository!

Happy Trading! 🚀📈
