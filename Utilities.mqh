#property strict

//+------------------------------------------------------------------+
//| Utilities.mqh - Utility functions for MQL5 trading               |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Pips conversion functions                                        |
//+------------------------------------------------------------------+

/**
 * Converts pips to points (price units).
 * @param pips - Number of pips to convert.
 * @param symbol - Symbol name (optional, defaults to current).
 * @return double - Points value.
 */
double PipsToPoints(double pips, string symbol = NULL)
{
   if(symbol == NULL) symbol = _Symbol;
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   return pips * point * 10.0;
}

/**
 * Converts points to pips.
 * @param points - Number of points to convert.
 * @param symbol - Symbol name (optional, defaults to current).
 * @return double - Pips value.
 */
double PointsToPips(double points, string symbol = NULL)
{
   if(symbol == NULL) symbol = _Symbol;
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point == 0.0) return 0.0;
   return points / (point * 10.0);
}

/**
 * Converts pips to price difference.
 * @param pips - Number of pips.
 * @param symbol - Symbol name (optional, defaults to current).
 * @return double - Price difference.
 */
double PipsToPrice(double pips, string symbol = NULL)
{
   return PipsToPoints(pips, symbol);
}

//+------------------------------------------------------------------+
//| Volume calculation functions                                     |
//+------------------------------------------------------------------+

/**
 * Calculates lot size based on risk percentage of equity.
 * @param entryPrice - Entry price for the trade.
 * @param stopLoss - Stop loss price.
 * @param riskPercent - Risk percentage (e.g., 1.0 for 1%).
 * @param symbol - Symbol name (optional, defaults to current).
 * @return double - Calculated lot size, normalized to symbol's lot step.
 */
double CalcLotSizeByRisk(double entryPrice, double stopLoss, double riskPercent, string symbol = NULL)
{
   if(symbol == NULL) symbol = _Symbol;
   
   // Get symbol properties
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   
   if(point == 0.0 || tickValue == 0.0) return minLot;
   
   // Calculate risk in money terms
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskMoney = equity * (riskPercent / 100.0);
   
   // Calculate SL distance in points
   double slDistancePoints = MathAbs(entryPrice - stopLoss) / point;
   if(slDistancePoints == 0.0) return minLot;
   
   // Calculate raw lot size
   double lotRaw = riskMoney / (slDistancePoints * point * tickValue);
   
   // Normalize to lot step and clamp to min/max
   double lot = NormalizeDouble(lotRaw / lotStep, 0) * lotStep;
   lot = MathMax(minLot, MathMin(maxLot, lot));
   
   return lot;
}

/**
 * Calculates lot size based on fixed lot amount.
 * @param fixedLot - Fixed lot size.
 * @param symbol - Symbol name (optional, defaults to current).
 * @return double - Normalized lot size.
 */
double CalcLotSizeFixed(double fixedLot, string symbol = NULL)
{
   if(symbol == NULL) symbol = _Symbol;
   
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   
   // Normalize to lot step and clamp to min/max
   double lot = NormalizeDouble(fixedLot / lotStep, 0) * lotStep;
   lot = MathMax(minLot, MathMin(maxLot, lot));
   
   return lot;
}

//+------------------------------------------------------------------+
//| Common MQL5 operations                                           |
//+------------------------------------------------------------------+

/**
 * Checks if a new bar has formed on the specified timeframe.
 * @param tf - Timeframe to check.
 * @param symbol - Symbol name (optional, defaults to current).
 * @return bool - True if new bar, false otherwise.
 */
bool IsNewBar(ENUM_TIMEFRAMES tf, string symbol = NULL)
{
   if(symbol == NULL) symbol = _Symbol;
   static datetime lastBarTime = 0;
   datetime currentBar = iTime(symbol, tf, 0);
   if(lastBarTime != currentBar)
   {
      lastBarTime = currentBar;
      return true;
   }
   return false;
}

/**
 * Gets indicator value safely with error checking.
 * @param handle - Indicator handle.
 * @param bufferNum - Buffer number.
 * @param shift - Shift from current bar (0 for current).
 * @return double - Indicator value or 0.0 on error.
 */
double GetIndicatorValue(int handle, int bufferNum, int shift)
{
   if(handle == INVALID_HANDLE) return 0.0;
   
   double value[1];
   int copied = CopyBuffer(handle, bufferNum, shift, 1, value);
   if(copied <= 0) return 0.0;
   
   return value[0];
}

/**
 * Normalizes price, stop loss, and take profit values with respect to stops level.
 * @param price - Entry price.
 * @param sl - Stop loss price.
 * @param tp - Take profit price.
 * @param orderType - Order type (ORDER_TYPE_BUY or ORDER_TYPE_SELL).
 * @param symbol - Symbol name (optional, defaults to current).
 * @return bool - True if normalization successful, false if stops violate minimum distance.
 */
bool NormalizePrices(double &price, double &sl, double &tp, ENUM_ORDER_TYPE orderType, string symbol = NULL)
{
   if(symbol == NULL) symbol = _Symbol;
   
   // Get stops level
   int stopsLevel = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double minDist = stopsLevel * point;
   if(minDist <= 0.0) minDist = 10.0 * point;
   
   // Normalize to digits
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   price = NormalizeDouble(price, digits);
   sl = NormalizeDouble(sl, digits);
   tp = NormalizeDouble(tp, digits);
   
   // Apply stops level constraints
   if(orderType == ORDER_TYPE_BUY || orderType == ORDER_TYPE_BUY_STOP || orderType == ORDER_TYPE_BUY_LIMIT)
   {
      if(sl > 0.0 && price - sl < minDist) return false;
      if(tp > 0.0 && tp - price < minDist) return false;
      
      // Clamp values
      if(sl > 0.0) sl = MathMin(sl, price - minDist);
      if(tp > 0.0) tp = MathMax(tp, price + minDist);
   }
   else if(orderType == ORDER_TYPE_SELL || orderType == ORDER_TYPE_SELL_STOP || orderType == ORDER_TYPE_SELL_LIMIT)
   {
      if(sl > 0.0 && sl - price < minDist) return false;
      if(tp > 0.0 && price - tp < minDist) return false;
      
      // Clamp values
      if(sl > 0.0) sl = MathMax(sl, price + minDist);
      if(tp > 0.0) tp = MathMin(tp, price - minDist);
   }
   
   return true;
}

/**
 * Calculates Asian Range (00:00-06:00 GMT) for the current day.
 * @param symbol - Symbol name (optional, defaults to current).
 * @param rangeHigh - Output: Highest high in the range.
 * @param rangeLow - Output: Lowest low in the range.
 * @return bool - True if range calculated successfully, false otherwise.
 */
bool CalculateAsianRange(double &rangeHigh, double &rangeLow, string symbol = NULL)
{
   if(symbol == NULL) symbol = _Symbol;
   
   datetime currentTime = TimeCurrent();
   MqlDateTime timeStruct;
   TimeToStruct(currentTime, timeStruct);
   
   // Set start and end times for Asian session (00:00-06:00 GMT)
   timeStruct.hour = 0;
   timeStruct.min = 0;
   timeStruct.sec = 0;
   datetime startTime = StructToTime(timeStruct);
   
   timeStruct.hour = 6;
   datetime endTime = StructToTime(timeStruct);
   
   // Initialize range values
   rangeHigh = -DBL_MAX;
   rangeLow = DBL_MAX;
   bool found = false;
   
   // Loop through D1 bars to find those within the time range
   for(int i = 0; i < 10; i++) // Check last 10 days for safety
   {
      datetime barTime = iTime(symbol, PERIOD_D1, i);
      if(barTime >= startTime && barTime < endTime)
      {
         double high = iHigh(symbol, PERIOD_D1, i);
         double low = iLow(symbol, PERIOD_D1, i);
         
         if(high > rangeHigh) rangeHigh = high;
         if(low < rangeLow) rangeLow = low;
         found = true;
      }
   }
   
   return found;
}

/**
 * Checks for breakout signal (long).
 * @param level - Breakout level.
 * @param tolerancePips - Tolerance in pips (optional, defaults to 0).
 * @param symbol - Symbol name (optional, defaults to current).
 * @return bool - True if breakout occurred, false otherwise.
 */
bool IsBreakoutLong(double level, double tolerancePips = 0, string symbol = NULL)
{
   if(symbol == NULL) symbol = _Symbol;
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   return ask > level + tolerancePips * point * 10.0;
}

/**
 * Checks for breakout signal (short).
 * @param level - Breakout level.
 * @param tolerancePips - Tolerance in pips (optional, defaults to 0).
 * @param symbol - Symbol name (optional, defaults to current).
 * @return bool - True if breakout occurred, false otherwise.
 */
bool IsBreakoutShort(double level, double tolerancePips = 0, string symbol = NULL)
{
   if(symbol == NULL) symbol = _Symbol;
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   return bid < level - tolerancePips * point * 10.0;
}

/**
 * Checks for retest after breakout (long).
 * @param level - Breakout level.
 * @param tolerancePips - Tolerance in pips.
 * @param symbol - Symbol name (optional, defaults to current).
 * @return bool - True if retest occurred, false otherwise.
 */
bool IsRetestLong(double level, double tolerancePips, string symbol = NULL)
{
   if(symbol == NULL) symbol = _Symbol;
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double tol = tolerancePips * point * 10.0;
   double lowBar = iLow(symbol, PERIOD_CURRENT, 1);
   double closeBar = iClose(symbol, PERIOD_CURRENT, 1);
   return (lowBar <= level + tol && closeBar > level);
}

/**
 * Checks for retest after breakout (short).
 * @param level - Breakout level.
 * @param tolerancePips - Tolerance in pips.
 * @param symbol - Symbol name (optional, defaults to current).
 * @return bool - True if retest occurred, false otherwise.
 */
bool IsRetestShort(double level, double tolerancePips, string symbol = NULL)
{
   if(symbol == NULL) symbol = _Symbol;
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double tol = tolerancePips * point * 10.0;
   double highBar = iHigh(symbol, PERIOD_CURRENT, 1);
   double closeBar = iClose(symbol, PERIOD_CURRENT, 1);
   return (highBar >= level - tol && closeBar < level);
}

/**
 * Checks for trend signal using MA crossover (long).
 * @param fastHandle - Handle to fast MA indicator.
 * @param slowHandle - Handle to slow MA indicator.
 * @param signalShift - Shift for signal calculation (optional, defaults to 0).
 * @return bool - True if crossover occurred, false otherwise.
 */
bool IsTrendLong(int fastHandle, int slowHandle, int signalShift = 0)
{
   double fast0 = GetIndicatorValue(fastHandle, 0, signalShift);
   double slow0 = GetIndicatorValue(slowHandle, 0, signalShift);
   double fast1 = GetIndicatorValue(fastHandle, 0, signalShift + 1);
   double slow1 = GetIndicatorValue(slowHandle, 0, signalShift + 1);
   return (fast1 <= slow1 && fast0 > slow0);
}

/**
 * Checks for trend signal using MA crossover (short).
 * @param fastHandle - Handle to fast MA indicator.
 * @param slowHandle - Handle to slow MA indicator.
 * @param signalShift - Shift for signal calculation (optional, defaults to 0).
 * @return bool - True if crossover occurred, false otherwise.
 */
bool IsTrendShort(int fastHandle, int slowHandle, int signalShift = 0)
{
   double fast0 = GetIndicatorValue(fastHandle, 0, signalShift);
   double slow0 = GetIndicatorValue(slowHandle, 0, signalShift);
   double fast1 = GetIndicatorValue(fastHandle, 0, signalShift + 1);
   double slow1 = GetIndicatorValue(slowHandle, 0, signalShift + 1);
   return (fast1 >= slow1 && fast0 < slow0);
}

//+------------------------------------------------------------------+
