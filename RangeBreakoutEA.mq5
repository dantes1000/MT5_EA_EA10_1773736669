#property copyright "Copyright 2023, RangeBreakoutEA"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>
#include <Trade/SymbolInfo.mqh>
#include <Indicators/Trend.mqh>
#include <Arrays/ArrayObj.mqh>

//--- Input Parameters
input bool   AllowLong = true;                 // Allow Long Trades
input bool   AllowShort = true;                // Allow Short Trades
input int    TradeStartHour = 6;               // Trade Start Hour (GMT)
input int    TradeEndHour = 22;                // Trade End Hour (GMT)
input bool   UseNewsFilter = false;            // Enable News Filter
input int    NewsMinutesBefore = 30;           // Minutes Before High Impact News
input int    NewsMinutesAfter = 30;            // Minutes After High Impact News
input int    TrendEMAPeriod = 50;              // Trend EMA Period (H1)
input double MarginPips = 5.0;                 // Margin Pips for SL
input int    TP_Method = 0;                    // TP Method: 0=Dynamic ATR, 1=Fixed R:R
input int    ATRPeriod = 14;                   // ATR Period (H1)
input double ATR_TP_Mult = 3.0;                // ATR Multiplier for TP
input double RiskRewardRatio = 1.5;            // Risk:Reward Ratio
input int    LotMethod = 0;                    // Lot Method: 0=% Equity, 1=Fixed
input double RiskPercent = 2.0;                // Risk % per Trade
input double FixedLot = 0.1;                   // Fixed Lot Size
input double MinLot = 0.01;                    // Minimum Lot Size
input double MaxLot = 100.0;                   // Maximum Lot Size
input double RetestTolerancePips = 2.0;        // Retest Tolerance Pips
input int    SignalShift = 0;                  // Signal Shift for Indicators
input bool   UseRetest = true;                 // Use Retest Entry
input bool   UseTrendFilter = true;            // Use Trend Filter
input int    MaxPositions = 1;                 // Maximum Open Positions
input int    MagicNumber = 123456;             // EA Magic Number
input string CommentText = "RangeBreakoutEA";  // Order Comment

//--- Global Variables
CTrade        trade;
CSymbolInfo   symbolInfo;
double        rangeHigh, rangeLow;
datetime      lastBarTime = 0;
int           atrHandle = -1;
int           emaHandle = -1;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber);
   if(!symbolInfo.Name(_Symbol))
      return INIT_FAILED;
   
   atrHandle = iATR(_Symbol, PERIOD_H1, ATRPeriod);
   emaHandle = iMA(_Symbol, PERIOD_H1, TrendEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   
   if(atrHandle == INVALID_HANDLE || emaHandle == INVALID_HANDLE)
      return INIT_FAILED;
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(atrHandle != INVALID_HANDLE)
      IndicatorRelease(atrHandle);
   if(emaHandle != INVALID_HANDLE)
      IndicatorRelease(emaHandle);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!IsNewBar(PERIOD_D1))
      return;
   
   CalculateAsianRange();
   
   if(!CheckTradingConditions())
      return;
   
   if(CountPositions() >= MaxPositions)
      return;
   
   CheckForBreakouts();
}

//+------------------------------------------------------------------+
//| Calculate Asian Range (00:00-06:00 GMT)                          |
//+------------------------------------------------------------------+
void CalculateAsianRange()
{
   rangeHigh = 0.0;
   rangeLow = DBL_MAX;
   datetime currentTime = TimeCurrent();
   datetime startOfDay = currentTime - (currentTime % 86400);
   
   for(int i = 0; i < 100; i++)
   {
      datetime barTime = iTime(_Symbol, PERIOD_D1, i);
      if(barTime < startOfDay)
         break;
      
      int hour = TimeHour(barTime);
      if(hour >= 0 && hour < 6)
      {
         double high = iHigh(_Symbol, PERIOD_D1, i);
         double low = iLow(_Symbol, PERIOD_D1, i);
         
         if(high > rangeHigh)
            rangeHigh = high;
         if(low < rangeLow)
            rangeLow = low;
      }
   }
   
   if(rangeLow == DBL_MAX)
      rangeLow = 0.0;
}

//+------------------------------------------------------------------+
//| Check Trading Conditions                                         |
//+------------------------------------------------------------------+
bool CheckTradingConditions()
{
   datetime currentTime = TimeCurrent();
   int hour = TimeHour(currentTime);
   int dayOfWeek = TimeDayOfWeek(currentTime);
   
   if(hour < TradeStartHour || hour >= TradeEndHour)
      return false;
   
   if(dayOfWeek == 0 || dayOfWeek == 6)
      return false;
   
   if(UseNewsFilter && IsHighImpactNewsTime())
      return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Check for High Impact News Time                                  |
//+------------------------------------------------------------------+
bool IsHighImpactNewsTime()
{
   // Placeholder for news checking logic
   // Implement using Calendar API or external source
   return false;
}

//+------------------------------------------------------------------+
//| Check for Breakouts                                              |
//+------------------------------------------------------------------+
void CheckForBreakouts()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   if(AllowLong && IsBreakoutLong(rangeHigh, 0))
   {
      if(!UseRetest || IsRetestLong(rangeHigh))
      {
         if(!UseTrendFilter || IsTrendLong())
         {
            double sl = rangeLow - MarginPips * _Point;
            double tp = CalculateTP(ask, sl, true);
            double lot = CalculateLotSize(ask, sl);
            OpenBuyStop(ask, sl, tp, lot);
         }
      }
   }
   
   if(AllowShort && IsBreakoutShort(rangeLow, 0))
   {
      if(!UseRetest || IsRetestShort(rangeLow))
      {
         if(!UseTrendFilter || IsTrendShort())
         {
            double sl = rangeHigh + MarginPips * _Point;
            double tp = CalculateTP(bid, sl, false);
            double lot = CalculateLotSize(bid, sl);
            OpenSellStop(bid, sl, tp, lot);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate Take Profit                                            |
//+------------------------------------------------------------------+
double CalculateTP(double entry, double sl, bool isBuy)
{
   double tp = 0.0;
   
   if(TP_Method == 0) // Dynamic ATR
   {
      double atrValue[1];
      if(CopyBuffer(atrHandle, 0, 0, 1, atrValue) > 0)
      {
         if(isBuy)
            tp = entry + ATR_TP_Mult * atrValue[0];
         else
            tp = entry - ATR_TP_Mult * atrValue[0];
      }
   }
   else if(TP_Method == 1) // Fixed R:R
   {
      double slDistancePoints = MathAbs(entry - sl) / _Point;
      if(isBuy)
         tp = entry + slDistancePoints * RiskRewardRatio * _Point;
      else
         tp = entry - slDistancePoints * RiskRewardRatio * _Point;
   }
   
   return NormalizeDouble(tp, _Digits);
}

//+------------------------------------------------------------------+
//| Calculate Lot Size                                               |
//+------------------------------------------------------------------+
double CalculateLotSize(double entry, double sl)
{
   double lotRaw = 0.0;
   
   if(LotMethod == 0) // % Equity
   {
      double riskMoney = AccountEquity() * (RiskPercent / 100.0);
      double slDistancePoints = MathAbs(entry - sl) / _Point;
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      
      if(tickValue > 0 && slDistancePoints > 0)
         lotRaw = riskMoney / (slDistancePoints * _Point * tickValue);
   }
   else if(LotMethod == 1) // Fixed Lot
   {
      lotRaw = FixedLot;
   }
   
   double lot = MathMax(MinLot, MathMin(MaxLot, NormalizeDouble(lotRaw, 2)));
   return lot;
}

//+------------------------------------------------------------------+
//| Open Buy Stop Order                                              |
//+------------------------------------------------------------------+
void OpenBuyStop(double price, double sl, double tp, double lot)
{
   double minDist = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   if(minDist <= 0)
      minDist = 10 * _Point;
   
   double slBuy = MathMin(sl, price - minDist);
   double tpBuy = MathMax(tp, price + minDist);
   
   slBuy = NormalizeDouble(slBuy, _Digits);
   tpBuy = NormalizeDouble(tpBuy, _Digits);
   price = NormalizeDouble(price, _Digits);
   
   trade.BuyStop(lot, price, _Symbol, slBuy, tpBuy, ORDER_TIME_GTC, 0, CommentText);
}

//+------------------------------------------------------------------+
//| Open Sell Stop Order                                             |
//+------------------------------------------------------------------+
void OpenSellStop(double price, double sl, double tp, double lot)
{
   double minDist = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   if(minDist <= 0)
      minDist = 10 * _Point;
   
   double slSell = MathMax(sl, price + minDist);
   double tpSell = MathMin(tp, price - minDist);
   
   slSell = NormalizeDouble(slSell, _Digits);
   tpSell = NormalizeDouble(tpSell, _Digits);
   price = NormalizeDouble(price, _Digits);
   
   trade.SellStop(lot, price, _Symbol, slSell, tpSell, ORDER_TIME_GTC, 0, CommentText);
}

//+------------------------------------------------------------------+
//| Count Open Positions                                             |
//+------------------------------------------------------------------+
int CountPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber &&
            PositionGetString(POSITION_SYMBOL) == _Symbol)
            count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| New Bar Detection                                                |
//+------------------------------------------------------------------+
bool IsNewBar(ENUM_TIMEFRAMES tf)
{
   datetime currentBar = iTime(_Symbol, tf, 0);
   if(lastBarTime != currentBar)
   {
      lastBarTime = currentBar;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Breakout Long Check                                              |
//+------------------------------------------------------------------+
bool IsBreakoutLong(double level, double tolerancePips = 0)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   return ask > level + tolerancePips * point * 10;
}

//+------------------------------------------------------------------+
//| Breakout Short Check                                             |
//+------------------------------------------------------------------+
bool IsBreakoutShort(double level, double tolerancePips = 0)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   return bid < level - tolerancePips * point * 10;
}

//+------------------------------------------------------------------+
//| Retest Long Check                                                |
//+------------------------------------------------------------------+
bool IsRetestLong(double level)
{
   double point   = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double tol     = RetestTolerancePips * point * 10;
   double lowBar  = iLow(_Symbol, PERIOD_CURRENT, 1);
   double closeBar = iClose(_Symbol, PERIOD_CURRENT, 1);
   return (lowBar <= level + tol && closeBar > level);
}

//+------------------------------------------------------------------+
//| Retest Short Check                                               |
//+------------------------------------------------------------------+
bool IsRetestShort(double level)
{
   double point    = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double tol      = RetestTolerancePips * point * 10;
   double highBar  = iHigh(_Symbol, PERIOD_CURRENT, 1);
   double closeBar = iClose(_Symbol, PERIOD_CURRENT, 1);
   return (highBar >= level - tol && closeBar < level);
}

//+------------------------------------------------------------------+
//| Trend Long Check                                                 |
//+------------------------------------------------------------------+
bool IsTrendLong()
{
   double emaValue[2];
   if(CopyBuffer(emaHandle, 0, 0, 2, emaValue) < 2)
      return false;
   
   double close0 = iClose(_Symbol, PERIOD_H1, 0);
   double close1 = iClose(_Symbol, PERIOD_H1, 1);
   
   return (close1 <= emaValue[1] && close0 > emaValue[0]);
}

//+------------------------------------------------------------------+
//| Trend Short Check                                                |
//+------------------------------------------------------------------+
bool IsTrendShort()
{
   double emaValue[2];
   if(CopyBuffer(emaHandle, 0, 0, 2, emaValue) < 2)
      return false;
   
   double close0 = iClose(_Symbol, PERIOD_H1, 0);
   double close1 = iClose(_Symbol, PERIOD_H1, 1);
   
   return (close1 >= emaValue[1] && close0 < emaValue[0]);
}

//+------------------------------------------------------------------+
//| Get Indicator Value                                              |
//+------------------------------------------------------------------+
double GetIndicatorValue(int handle, int buffer, int shift)
{
   double value[1];
   if(CopyBuffer(handle, buffer, shift, 1, value) > 0)
      return value[0];
   return 0.0;
}
