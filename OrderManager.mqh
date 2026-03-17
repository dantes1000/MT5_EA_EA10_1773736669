//+------------------------------------------------------------------+
//|                                                      OrderManager.mqh |
//|                        Copyright 2023, MetaQuotes Ltd.            |
//|                                             https://www.mql5.com  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| OrderManager class                                               |
//+------------------------------------------------------------------+
class COrderManager
{
private:
   // Configuration parameters
   double            m_margin_pips;          // Margin in pips for SL calculation
   int               m_tp_method;            // 0=ATR, 1=Fixed R:R
   double            m_atr_tp_mult;          // ATR multiplier for TP
   double            m_rr_ratio;             // Risk:Reward ratio
   int               m_lot_method;           // 0=% Equity, 1=Fixed lot
   double            m_risk_percent;         // Risk percentage for equity method
   double            m_fixed_lot;            // Fixed lot size
   double            m_min_lot;              // Minimum lot size
   double            m_max_lot;              // Maximum lot size
   
   // Internal handles
   int               m_atr_handle;           // ATR indicator handle
   
   // Helper methods
   double            CalcAsianRangeHigh();
   double            CalcAsianRangeLow();
   double            CalcStopLossBuy(double entry);
   double            CalcStopLossSell(double entry);
   double            CalcTakeProfitBuy(double entry, double sl);
   double            CalcTakeProfitSell(double entry, double sl);
   double            CalcLotSize(double entry, double sl);
   double            NormalizePrice(double price);
   double            NormalizeSLTP(double price, double entry, bool is_buy);
   
public:
   // Constructor
   COrderManager(double margin_pips = 5.0, 
                 int tp_method = 0, 
                 double atr_tp_mult = 3.0, 
                 double rr_ratio = 1.5, 
                 int lot_method = 0, 
                 double risk_percent = 1.0, 
                 double fixed_lot = 0.01);
   
   // Destructor
   ~COrderManager();
   
   // Main order placement methods
   bool              PlaceBuyStopOrder(double entry_price, string comment = "");
   bool              PlaceSellStopOrder(double entry_price, string comment = "");
   
   // Configuration methods
   void              SetMarginPips(double pips) { m_margin_pips = pips; }
   void              SetTPMethod(int method) { m_tp_method = method; }
   void              SetATRMultiplier(double mult) { m_atr_tp_mult = mult; }
   void              SetRRRatio(double ratio) { m_rr_ratio = ratio; }
   void              SetLotMethod(int method) { m_lot_method = method; }
   void              SetRiskPercent(double percent) { m_risk_percent = percent; }
   void              SetFixedLot(double lot) { m_fixed_lot = lot; }
   void              SetLotLimits(double min_lot, double max_lot) { m_min_lot = min_lot; m_max_lot = max_lot; }
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
COrderManager::COrderManager(double margin_pips, 
                             int tp_method, 
                             double atr_tp_mult, 
                             double rr_ratio, 
                             int lot_method, 
                             double risk_percent, 
                             double fixed_lot)
{
   m_margin_pips = margin_pips;
   m_tp_method = tp_method;
   m_atr_tp_mult = atr_tp_mult;
   m_rr_ratio = rr_ratio;
   m_lot_method = lot_method;
   m_risk_percent = risk_percent;
   m_fixed_lot = fixed_lot;
   
   // Initialize lot limits from symbol properties
   m_min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   m_max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   
   // Create ATR handle for TP calculation
   m_atr_handle = iATR(_Symbol, PERIOD_H1, 14);
   if(m_atr_handle == INVALID_HANDLE)
   {
      Print("Failed to create ATR handle");
   }
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
COrderManager::~COrderManager()
{
   if(m_atr_handle != INVALID_HANDLE)
   {
      IndicatorRelease(m_atr_handle);
   }
}

//+------------------------------------------------------------------+
//| Calculate Asian Range High (00:00-06:00 GMT)                     |
//+------------------------------------------------------------------+
double COrderManager::CalcAsianRangeHigh()
{
   double range_high = 0;
   datetime current_time = TimeCurrent();
   datetime start_time = StringToTime(TimeToString(current_time, TIME_DATE) + " 00:00");
   datetime end_time = StringToTime(TimeToString(current_time, TIME_DATE) + " 06:00");
   
   // Find highest high within Asian session
   for(int i = 0; i < 100; i++)
   {
      datetime bar_time = iTime(_Symbol, PERIOD_D1, i);
      if(bar_time < start_time) break;
      
      if(bar_time >= start_time && bar_time < end_time)
      {
         double high = iHigh(_Symbol, PERIOD_D1, i);
         if(range_high == 0 || high > range_high)
         {
            range_high = high;
         }
      }
   }
   
   return range_high;
}

//+------------------------------------------------------------------+
//| Calculate Asian Range Low (00:00-06:00 GMT)                      |
//+------------------------------------------------------------------+
double COrderManager::CalcAsianRangeLow()
{
   double range_low = 0;
   datetime current_time = TimeCurrent();
   datetime start_time = StringToTime(TimeToString(current_time, TIME_DATE) + " 00:00");
   datetime end_time = StringToTime(TimeToString(current_time, TIME_DATE) + " 06:00");
   
   // Find lowest low within Asian session
   for(int i = 0; i < 100; i++)
   {
      datetime bar_time = iTime(_Symbol, PERIOD_D1, i);
      if(bar_time < start_time) break;
      
      if(bar_time >= start_time && bar_time < end_time)
      {
         double low = iLow(_Symbol, PERIOD_D1, i);
         if(range_low == 0 || low < range_low)
         {
            range_low = low;
         }
      }
   }
   
   return range_low;
}

//+------------------------------------------------------------------+
//| Calculate Stop Loss for Buy Stop order                           |
//+------------------------------------------------------------------+
double COrderManager::CalcStopLossBuy(double entry)
{
   double range_low = CalcAsianRangeLow();
   if(range_low == 0) return 0;
   
   // SL = range_low - margin_pips
   double sl = range_low - (m_margin_pips * _Point * 10);
   return sl;
}

//+------------------------------------------------------------------+
//| Calculate Stop Loss for Sell Stop order                          |
//+------------------------------------------------------------------+
double COrderManager::CalcStopLossSell(double entry)
{
   double range_high = CalcAsianRangeHigh();
   if(range_high == 0) return 0;
   
   // SL = range_high + margin_pips
   double sl = range_high + (m_margin_pips * _Point * 10);
   return sl;
}

//+------------------------------------------------------------------+
//| Calculate Take Profit for Buy Stop order                         |
//+------------------------------------------------------------------+
double COrderManager::CalcTakeProfitBuy(double entry, double sl)
{
   if(sl == 0) return 0;
   
   double tp = 0;
   
   if(m_tp_method == 0) // ATR method
   {
      if(m_atr_handle != INVALID_HANDLE)
      {
         double atr_buffer[1];
         if(CopyBuffer(m_atr_handle, 0, 0, 1, atr_buffer) == 1)
         {
            tp = entry + (m_atr_tp_mult * atr_buffer[0]);
         }
      }
   }
   else if(m_tp_method == 1) // Fixed R:R method
   {
      double sl_distance_points = MathAbs(entry - sl) / _Point;
      tp = entry + (sl_distance_points * m_rr_ratio * _Point);
   }
   
   return tp;
}

//+------------------------------------------------------------------+
//| Calculate Take Profit for Sell Stop order                        |
//+------------------------------------------------------------------+
double COrderManager::CalcTakeProfitSell(double entry, double sl)
{
   if(sl == 0) return 0;
   
   double tp = 0;
   
   if(m_tp_method == 0) // ATR method
   {
      if(m_atr_handle != INVALID_HANDLE)
      {
         double atr_buffer[1];
         if(CopyBuffer(m_atr_handle, 0, 0, 1, atr_buffer) == 1)
         {
            tp = entry - (m_atr_tp_mult * atr_buffer[0]);
         }
      }
   }
   else if(m_tp_method == 1) // Fixed R:R method
   {
      double sl_distance_points = MathAbs(entry - sl) / _Point;
      tp = entry - (sl_distance_points * m_rr_ratio * _Point);
   }
   
   return tp;
}

//+------------------------------------------------------------------+
//| Calculate lot size                                               |
//+------------------------------------------------------------------+
double COrderManager::CalcLotSize(double entry, double sl)
{
   double lot_raw = 0;
   
   if(m_lot_method == 0) // % Equity method
   {
      if(sl == 0) return m_min_lot;
      
      double risk_money = AccountEquity() * (m_risk_percent / 100.0);
      double sl_distance_points = MathAbs(entry - sl) / _Point;
      double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      
      // Adjust for non-USD quote currency if needed
      if(tick_value == 0) tick_value = 1.0;
      
      lot_raw = risk_money / (sl_distance_points * _Point * tick_value);
   }
   else if(m_lot_method == 1) // Fixed lot method
   {
      lot_raw = m_fixed_lot;
   }
   
   // Apply lot limits and normalize
   double lot = MathMax(m_min_lot, MathMin(m_max_lot, NormalizeDouble(lot_raw, 2)));
   return lot;
}

//+------------------------------------------------------------------+
//| Normalize price to symbol digits                                 |
//+------------------------------------------------------------------+
double COrderManager::NormalizePrice(double price)
{
   return NormalizeDouble(price, _Digits);
}

//+------------------------------------------------------------------+
//| Normalize SL/TP with respect to SYMBOL_TRADE_STOPS_LEVEL         |
//+------------------------------------------------------------------+
double COrderManager::NormalizeSLTP(double price, double entry, bool is_buy)
{
   // Get minimum distance from stops level
   long stops_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double min_dist = stops_level * _Point;
   if(min_dist <= 0) min_dist = 10 * _Point;
   
   // Clamp SL/TP based on order type
   if(is_buy)
   {
      // For buy orders: SL must be below entry - min_dist, TP must be above entry + min_dist
      if(price < entry) // This is SL
      {
         return MathMin(price, entry - min_dist);
      }
      else // This is TP
      {
         return MathMax(price, entry + min_dist);
      }
   }
   else
   {
      // For sell orders: SL must be above entry + min_dist, TP must be below entry - min_dist
      if(price > entry) // This is SL
      {
         return MathMax(price, entry + min_dist);
      }
      else // This is TP
      {
         return MathMin(price, entry - min_dist);
      }
   }
}

//+------------------------------------------------------------------+
//| Place Buy Stop order                                             |
//+------------------------------------------------------------------+
bool COrderManager::PlaceBuyStopOrder(double entry_price, string comment = "")
{
   // Calculate SL and TP
   double sl = CalcStopLossBuy(entry_price);
   double tp = CalcTakeProfitBuy(entry_price, sl);
   
   if(sl == 0 || tp == 0)
   {
      Print("Failed to calculate SL/TP for Buy Stop order");
      return false;
   }
   
   // Calculate lot size
   double lot = CalcLotSize(entry_price, sl);
   
   // Normalize all prices
   entry_price = NormalizePrice(entry_price);
   sl = NormalizePrice(sl);
   tp = NormalizePrice(tp);
   
   // Apply stops level normalization
   sl = NormalizeSLTP(sl, entry_price, true);
   tp = NormalizeSLTP(tp, entry_price, true);
   
   // Prepare trade request
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_PENDING;
   request.symbol = _Symbol;
   request.volume = lot;
   request.type = ORDER_TYPE_BUY_STOP;
   request.price = entry_price;
   request.sl = sl;
   request.tp = tp;
   request.deviation = 10;
   request.magic = 12345;
   request.comment = comment;
   request.type_filling = ORDER_FILLING_FOK;
   request.type_time = ORDER_TIME_GTC;
   
   // Send order
   if(!OrderSend(request, result))
   {
      Print("Buy Stop order failed. Error: ", GetLastError());
      return false;
   }
   
   Print("Buy Stop order placed. Ticket: ", result.order);
   return true;
}

//+------------------------------------------------------------------+
//| Place Sell Stop order                                            |
//+------------------------------------------------------------------+
bool COrderManager::PlaceSellStopOrder(double entry_price, string comment = "")
{
   // Calculate SL and TP
   double sl = CalcStopLossSell(entry_price);
   double tp = CalcTakeProfitSell(entry_price, sl);
   
   if(sl == 0 || tp == 0)
   {
      Print("Failed to calculate SL/TP for Sell Stop order");
      return false;
   }
   
   // Calculate lot size
   double lot = CalcLotSize(entry_price, sl);
   
   // Normalize all prices
   entry_price = NormalizePrice(entry_price);
   sl = NormalizePrice(sl);
   tp = NormalizePrice(tp);
   
   // Apply stops level normalization
   sl = NormalizeSLTP(sl, entry_price, false);
   tp = NormalizeSLTP(tp, entry_price, false);
   
   // Prepare trade request
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_PENDING;
   request.symbol = _Symbol;
   request.volume = lot;
   request.type = ORDER_TYPE_SELL_STOP;
   request.price = entry_price;
   request.sl = sl;
   request.tp = tp;
   request.deviation = 10;
   request.magic = 12345;
   request.comment = comment;
   request.type_filling = ORDER_FILLING_FOK;
   request.type_time = ORDER_TIME_GTC;
   
   // Send order
   if(!OrderSend(request, result))
   {
      Print("Sell Stop order failed. Error: ", GetLastError());
      return false;
   }
   
   Print("Sell Stop order placed. Ticket: ", result.order);
   return true;
}
//+------------------------------------------------------------------+