//+------------------------------------------------------------------+
//| RiskManager.mqh                                                  |
//| Handles lot size calculation based on equity percentage or fixed |
//| lot, with risk management and position sizing logic.             |
//+------------------------------------------------------------------+
#property copyright ""
#property link      ""
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| RiskManager class                                                |
//+------------------------------------------------------------------+
class RiskManager
{
private:
   // Configuration parameters
   int      m_lotMethod;          // 0 = % equity, 1 = fixed lot
   double   m_riskPercent;        // Risk percentage (e.g., 2.0 for 2%)
   double   m_fixedLot;           // Fixed lot size
   double   m_minLot;             // Minimum lot size allowed
   double   m_maxLot;             // Maximum lot size allowed
   int      m_tpMethod;           // 0 = ATR dynamic, 1 = fixed R:R
   double   m_atrTpMult;          // ATR multiplier for TP
   double   m_riskRewardRatio;    // Risk:Reward ratio
   int      m_atrPeriod;          // ATR period for dynamic TP
   int      m_marginPips;         // Margin pips for SL calculation
   
   // Internal state
   double   m_rangeHigh;          // Asian range high (D1 00:00-06:00 GMT)
   double   m_rangeLow;           // Asian range low (D1 00:00-06:00 GMT)
   int      m_atrHandle;          // Handle for ATR indicator
   
public:
   // Constructor
   RiskManager() : m_lotMethod(0), m_riskPercent(2.0), m_fixedLot(0.01),
                   m_minLot(0.01), m_maxLot(100.0), m_tpMethod(0),
                   m_atrTpMult(3.0), m_riskRewardRatio(1.5),
                   m_atrPeriod(14), m_marginPips(5),
                   m_rangeHigh(0.0), m_rangeLow(0.0), m_atrHandle(INVALID_HANDLE)
   {
      // Initialize ATR indicator handle
      m_atrHandle = iATR(_Symbol, PERIOD_H1, m_atrPeriod);
      if(m_atrHandle == INVALID_HANDLE)
         Print("Failed to create ATR handle");
   }
   
   // Destructor
   ~RiskManager()
   {
      if(m_atrHandle != INVALID_HANDLE)
         IndicatorRelease(m_atrHandle);
   }
   
   // Setters for configuration
   void SetLotMethod(int method) { m_lotMethod = method; }
   void SetRiskPercent(double percent) { m_riskPercent = percent; }
   void SetFixedLot(double lot) { m_fixedLot = lot; }
   void SetMinLot(double min) { m_minLot = min; }
   void SetMaxLot(double max) { m_maxLot = max; }
   void SetTpMethod(int method) { m_tpMethod = method; }
   void SetAtrTpMult(double mult) { m_atrTpMult = mult; }
   void SetRiskRewardRatio(double ratio) { m_riskRewardRatio = ratio; }
   void SetAtrPeriod(int period) 
   { 
      m_atrPeriod = period; 
      if(m_atrHandle != INVALID_HANDLE)
         IndicatorRelease(m_atrHandle);
      m_atrHandle = iATR(_Symbol, PERIOD_H1, m_atrPeriod);
   }
   void SetMarginPips(int pips) { m_marginPips = pips; }
   
   // Calculate Asian range (D1 00:00-06:00 GMT)
   void CalculateAsianRange()
   {
      m_rangeHigh = 0.0;
      m_rangeLow = DBL_MAX;
      
      datetime currentTime = TimeCurrent();
      datetime startOfDay = iTime(_Symbol, PERIOD_D1, 0);
      
      // Check candles from today
      for(int i = 0; i < 10; i++) // Check up to 10 days back
      {
         datetime candleTime = iTime(_Symbol, PERIOD_D1, i);
         if(candleTime < startOfDay)
            break;
            
         // Check if candle opens between 00:00 and 06:00 GMT
         MqlDateTime dt;
         TimeToStruct(candleTime, dt);
         
         if(dt.hour >= 0 && dt.hour < 6)
         {
            double high = iHigh(_Symbol, PERIOD_D1, i);
            double low = iLow(_Symbol, PERIOD_D1, i);
            
            if(high > m_rangeHigh)
               m_rangeHigh = high;
            
            if(low < m_rangeLow)
               m_rangeLow = low;
         }
      }
      
      // If no candles found in range, use current day's range
      if(m_rangeHigh == 0.0 || m_rangeLow == DBL_MAX)
      {
         m_rangeHigh = iHigh(_Symbol, PERIOD_D1, 0);
         m_rangeLow = iLow(_Symbol, PERIOD_D1, 0);
      }
   }
   
   // Get Asian range high
   double GetRangeHigh() const { return m_rangeHigh; }
   
   // Get Asian range low
   double GetRangeLow() const { return m_rangeLow; }
   
   // Calculate Stop Loss for BUY STOP order (breakout of rangeHigh)
   double CalculateSLBuy(double entryPrice) const
   {
      double sl = m_rangeLow - (m_marginPips * _Point);
      
      // Apply SYMBOL_TRADE_STOPS_LEVEL constraint
      double minDist = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
      if(minDist <= 0)
         minDist = 10 * _Point;
      
      sl = MathMin(sl, entryPrice - minDist);
      return NormalizeDouble(sl, _Digits);
   }
   
   // Calculate Stop Loss for SELL STOP order (breakout of rangeLow)
   double CalculateSLSell(double entryPrice) const
   {
      double sl = m_rangeHigh + (m_marginPips * _Point);
      
      // Apply SYMBOL_TRADE_STOPS_LEVEL constraint
      double minDist = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
      if(minDist <= 0)
         minDist = 10 * _Point;
      
      sl = MathMax(sl, entryPrice + minDist);
      return NormalizeDouble(sl, _Digits);
   }
   
   // Calculate Take Profit
   double CalculateTP(double entryPrice, double slPrice, ENUM_ORDER_TYPE orderType) const
   {
      double tp = 0.0;
      
      if(m_tpMethod == 0) // Dynamic ATR
      {
         double atrValue = 0.0;
         if(m_atrHandle != INVALID_HANDLE)
         {
            double buf[1];
            if(CopyBuffer(m_atrHandle, 0, 0, 1, buf) == 1)
               atrValue = buf[0];
         }
         
         if(orderType == ORDER_TYPE_BUY || orderType == ORDER_TYPE_BUY_STOP)
            tp = entryPrice + (m_atrTpMult * atrValue);
         else if(orderType == ORDER_TYPE_SELL || orderType == ORDER_TYPE_SELL_STOP)
            tp = entryPrice - (m_atrTpMult * atrValue);
      }
      else if(m_tpMethod == 1) // Fixed R:R ratio
      {
         double slDistancePoints = MathAbs(entryPrice - slPrice) / _Point;
         
         if(orderType == ORDER_TYPE_BUY || orderType == ORDER_TYPE_BUY_STOP)
            tp = entryPrice + (slDistancePoints * m_riskRewardRatio * _Point);
         else if(orderType == ORDER_TYPE_SELL || orderType == ORDER_TYPE_SELL_STOP)
            tp = entryPrice - (slDistancePoints * m_riskRewardRatio * _Point);
      }
      
      // Apply SYMBOL_TRADE_STOPS_LEVEL constraint
      double minDist = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
      if(minDist <= 0)
         minDist = 10 * _Point;
      
      if(orderType == ORDER_TYPE_BUY || orderType == ORDER_TYPE_BUY_STOP)
         tp = MathMax(tp, entryPrice + minDist);
      else if(orderType == ORDER_TYPE_SELL || orderType == ORDER_TYPE_SELL_STOP)
         tp = MathMin(tp, entryPrice - minDist);
      
      return NormalizeDouble(tp, _Digits);
   }
   
   // Calculate lot size
   double CalculateLotSize(double entryPrice, double slPrice, ENUM_ORDER_TYPE orderType)
   {
      double lotRaw = 0.0;
      
      if(m_lotMethod == 0) // % of equity
      {
         double riskMoney = AccountEquity() * (m_riskPercent / 100.0);
         double slDistancePoints = MathAbs(entryPrice - slPrice) / _Point;
         double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
         
         // Adjust for non-USD quote currency if needed
         string baseCurrency = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_BASE);
         string profitCurrency = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_PROFIT);
         
         if(profitCurrency != "USD")
         {
            // Convert tick value to account currency (USD)
            string accountCurrency = AccountInfoString(ACCOUNT_CURRENCY);
            if(accountCurrency != profitCurrency)
            {
               // Simple conversion - in real implementation, use proper conversion rates
               tickValue = tickValue * 1.0; // Placeholder for actual conversion
            }
         }
         
         if(slDistancePoints > 0 && tickValue > 0)
            lotRaw = riskMoney / (slDistancePoints * _Point * tickValue);
      }
      else if(m_lotMethod == 1) // Fixed lot
      {
         lotRaw = m_fixedLot;
      }
      
      // Apply min/max constraints and normalize
      double lot = MathMax(m_minLot, MathMin(m_maxLot, NormalizeDouble(lotRaw, 2)));
      
      // Round to step size
      double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      if(lotStep > 0)
         lot = MathRound(lot / lotStep) * lotStep;
      
      return NormalizeDouble(lot, 2);
   }
   
   // Validate trade parameters
   bool ValidateTrade(double entryPrice, double slPrice, double tpPrice, double lotSize, ENUM_ORDER_TYPE orderType)
   {
      // Check lot size
      if(lotSize < m_minLot || lotSize > m_maxLot)
         return false;
      
      // Check stop levels
      double minDist = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
      if(minDist <= 0)
         minDist = 10 * _Point;
      
      if(orderType == ORDER_TYPE_BUY || orderType == ORDER_TYPE_BUY_STOP)
      {
         if(slPrice >= entryPrice - minDist)
            return false;
         if(tpPrice <= entryPrice + minDist)
            return false;
      }
      else if(orderType == ORDER_TYPE_SELL || orderType == ORDER_TYPE_SELL_STOP)
      {
         if(slPrice <= entryPrice + minDist)
            return false;
         if(tpPrice >= entryPrice - minDist)
            return false;
      }
      
      // Check margin requirements
      double marginRequired = 0.0;
      if(!OrderCalcMargin(orderType, _Symbol, lotSize, entryPrice, marginRequired))
         return false;
      
      if(marginRequired > AccountFreeMargin())
         return false;
      
      return true;
   }
   
   // Get risk per trade in monetary terms
   double GetRiskPerTrade(double entryPrice, double slPrice, double lotSize)
   {
      double slDistancePoints = MathAbs(entryPrice - slPrice) / _Point;
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      
      return slDistancePoints * _Point * tickValue * lotSize;
   }
   
   // Get risk as percentage of equity
   double GetRiskPercent(double entryPrice, double slPrice, double lotSize)
   {
      double riskMoney = GetRiskPerTrade(entryPrice, slPrice, lotSize);
      double equity = AccountEquity();
      
      if(equity > 0)
         return (riskMoney / equity) * 100.0;
      
      return 0.0;
   }
   
   // Update function to be called regularly
   void Update()
   {
      CalculateAsianRange();
   }
};

//+------------------------------------------------------------------+
//| Helper functions from reference patterns                         |
//+------------------------------------------------------------------+

// New bar detection
bool IsNewBar(ENUM_TIMEFRAMES tf)
{
   static datetime lastBarTime = 0;
   datetime currentBar = iTime(_Symbol, tf, 0);
   if(lastBarTime != currentBar)
   {
      lastBarTime = currentBar;
      return true;
   }
   return false;
}

// Breakout entry
bool IsBreakoutLong(double level, double tolerancePips = 0)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   return ask > level + tolerancePips * point * 10;
}

bool IsBreakoutShort(double level, double tolerancePips = 0)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   return bid < level - tolerancePips * point * 10;
}

// Retest check after breakout
bool IsRetestLong(double level, double retestTolerancePips)
{
   double point   = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double tol     = retestTolerancePips * point * 10;
   double lowBar  = iLow(_Symbol, PERIOD_CURRENT, 1);
   double closeBar = iClose(_Symbol, PERIOD_CURRENT, 1);
   return (lowBar <= level + tol && closeBar > level);
}

bool IsRetestShort(double level, double retestTolerancePips)
{
   double point    = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double tol      = retestTolerancePips * point * 10;
   double highBar  = iHigh(_Symbol, PERIOD_CURRENT, 1);
   double closeBar = iClose(_Symbol, PERIOD_CURRENT, 1);
   return (highBar >= level - tol && closeBar < level);
}

// Trend entry (MA crossover)
double GetIndicatorValue(int handle, int buffer, int shift)
{
   double value = 0.0;
   double buf[1];
   if(CopyBuffer(handle, buffer, shift, 1, buf) == 1)
      value = buf[0];
   return value;
}

bool IsTrendLong(int fastHandle, int slowHandle, int signalShift)
{
   double fast0 = GetIndicatorValue(fastHandle, 0, signalShift);
   double slow0 = GetIndicatorValue(slowHandle, 0, signalShift);
   double fast1 = GetIndicatorValue(fastHandle, 0, signalShift + 1);
   double slow1 = GetIndicatorValue(slowHandle, 0, signalShift + 1);
   return (fast1 <= slow1 && fast0 > slow0);
}

bool IsTrendShort(int fastHandle, int slowHandle, int signalShift)
{
   double fast0 = GetIndicatorValue(fastHandle, 0, signalShift);
   double slow0 = GetIndicatorValue(slowHandle, 0, signalShift);
   double fast1 = GetIndicatorValue(fastHandle, 0, signalShift + 1);
   double slow1 = GetIndicatorValue(slowHandle, 0, signalShift + 1);
   return (fast1 >= slow1 && fast0 < slow0);
}

//+------------------------------------------------------------------+
