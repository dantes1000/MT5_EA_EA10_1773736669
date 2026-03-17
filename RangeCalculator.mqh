#property strict

// RangeCalculator.mqh - Calculates Asian session range and SL/TP based on range with margin
// Version 1.0

class CRangeCalculator
{
private:
    string m_symbol;
    ENUM_TIMEFRAMES m_timeframe;
    int m_session_start_hour;  // GMT hour
    int m_session_end_hour;    // GMT hour
    double m_range_high;
    double m_range_low;
    datetime m_last_calc_time;
    
    // Helper function to get time from bar index
    datetime GetBarTime(int shift)
    {
        datetime times[1];
        if(CopyTime(m_symbol, m_timeframe, shift, 1, times) == 1)
            return times[0];
        return 0;
    }
    
    // Helper function to get high from bar index
    double GetHigh(int shift)
    {
        double highs[1];
        if(CopyHigh(m_symbol, m_timeframe, shift, 1, highs) == 1)
            return highs[0];
        return 0.0;
    }
    
    // Helper function to get low from bar index
    double GetLow(int shift)
    {
        double lows[1];
        if(CopyLow(m_symbol, m_timeframe, shift, 1, lows) == 1)
            return lows[0];
        return 0.0;
    }
    
public:
    // Constructor
    CRangeCalculator(string symbol = NULL, ENUM_TIMEFRAMES timeframe = PERIOD_D1, 
                     int session_start_hour = 0, int session_end_hour = 6)
    {
        m_symbol = (symbol == NULL) ? _Symbol : symbol;
        m_timeframe = timeframe;
        m_session_start_hour = session_start_hour;
        m_session_end_hour = session_end_hour;
        m_range_high = 0.0;
        m_range_low = 0.0;
        m_last_calc_time = 0;
    }
    
    // Calculate Asian session range for current day
    bool CalculateRange()
    {
        datetime current_time = TimeCurrent();
        
        // Check if we already calculated for today
        if(TimeDay(m_last_calc_time) == TimeDay(current_time) && 
           TimeMonth(m_last_calc_time) == TimeMonth(current_time) && 
           TimeYear(m_last_calc_time) == TimeYear(current_time))
        {
            return true;
        }
        
        // Reset values
        m_range_high = 0.0;
        m_range_low = 0.0;
        
        // Get today's date at 00:00
        MqlDateTime today_struct;
        TimeToStruct(current_time, today_struct);
        today_struct.hour = 0;
        today_struct.min = 0;
        today_struct.sec = 0;
        datetime today_start = StructToTime(today_struct);
        
        // Calculate session start and end times
        datetime session_start = today_start + (m_session_start_hour * 3600);
        datetime session_end = today_start + (m_session_end_hour * 3600);
        
        // Find bars within the session
        int bars = Bars(m_symbol, m_timeframe);
        bool first_bar = true;
        
        for(int i = 0; i < bars; i++)
        {
            datetime bar_time = GetBarTime(i);
            if(bar_time == 0) continue;
            
            // Check if bar is from today
            MqlDateTime bar_struct;
            TimeToStruct(bar_time, bar_struct);
            
            if(bar_struct.day == today_struct.day && 
               bar_struct.mon == today_struct.mon && 
               bar_struct.year == today_struct.year)
            {
                // Check if bar opening time is within session hours
                if(bar_struct.hour >= m_session_start_hour && bar_struct.hour < m_session_end_hour)
                {
                    double high = GetHigh(i);
                    double low = GetLow(i);
                    
                    if(first_bar)
                    {
                        m_range_high = high;
                        m_range_low = low;
                        first_bar = false;
                    }
                    else
                    {
                        if(high > m_range_high) m_range_high = high;
                        if(low < m_range_low) m_range_low = low;
                    }
                }
            }
            else if(bar_struct.day < today_struct.day)
            {
                // We've gone past today, break the loop
                break;
            }
        }
        
        m_last_calc_time = current_time;
        return (!first_bar);
    }
    
    // Get calculated range high
    double GetRangeHigh()
    {
        return m_range_high;
    }
    
    // Get calculated range low
    double GetRangeLow()
    {
        return m_range_low;
    }
    
    // Calculate SL for BUY STOP order (breakout above range high)
    double CalculateSLBuy(double margin_pips)
    {
        if(m_range_low <= 0.0) return 0.0;
        
        double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
        double sl = m_range_low - (margin_pips * point * 10);
        
        // Apply stops level constraint
        double minDist = SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
        if(minDist <= 0) minDist = 10 * point;
        
        // For SL calculation, we don't have entry price yet, so just normalize
        sl = NormalizeDouble(sl, (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS));
        
        return sl;
    }
    
    // Calculate SL for SELL STOP order (breakout below range low)
    double CalculateSLSell(double margin_pips)
    {
        if(m_range_high <= 0.0) return 0.0;
        
        double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
        double sl = m_range_high + (margin_pips * point * 10);
        
        // Apply stops level constraint
        double minDist = SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
        if(minDist <= 0) minDist = 10 * point;
        
        // For SL calculation, we don't have entry price yet, so just normalize
        sl = NormalizeDouble(sl, (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS));
        
        return sl;
    }
    
    // Calculate TP for BUY order
    double CalculateTPBuy(double entry_price, double sl_price, int tp_method, 
                         double atr_multiplier = 3.0, double risk_reward_ratio = 1.5,
                         int atr_period = 14, ENUM_TIMEFRAMES atr_tf = PERIOD_H1)
    {
        if(entry_price <= 0.0 || sl_price <= 0.0) return 0.0;
        
        double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
        double tp = 0.0;
        
        if(tp_method == 0) // Dynamic ATR
        {
            int atr_handle = iATR(m_symbol, atr_tf, atr_period);
            if(atr_handle != INVALID_HANDLE)
            {
                double atr_buffer[1];
                if(CopyBuffer(atr_handle, 0, 0, 1, atr_buffer) == 1)
                {
                    double atr_value = atr_buffer[0];
                    tp = entry_price + (atr_multiplier * atr_value);
                }
                IndicatorRelease(atr_handle);
            }
        }
        else if(tp_method == 1) // Fixed Risk:Reward ratio
        {
            double sl_distance_points = MathAbs(entry_price - sl_price) / point;
            tp = entry_price + (sl_distance_points * risk_reward_ratio * point);
        }
        
        // Apply stops level constraint
        double minDist = SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
        if(minDist <= 0) minDist = 10 * point;
        
        // For BUY, TP must be above entry + minDist
        tp = MathMax(tp, entry_price + minDist);
        tp = NormalizeDouble(tp, (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS));
        
        return tp;
    }
    
    // Calculate TP for SELL order
    double CalculateTPSell(double entry_price, double sl_price, int tp_method, 
                          double atr_multiplier = 3.0, double risk_reward_ratio = 1.5,
                          int atr_period = 14, ENUM_TIMEFRAMES atr_tf = PERIOD_H1)
    {
        if(entry_price <= 0.0 || sl_price <= 0.0) return 0.0;
        
        double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
        double tp = 0.0;
        
        if(tp_method == 0) // Dynamic ATR
        {
            int atr_handle = iATR(m_symbol, atr_tf, atr_period);
            if(atr_handle != INVALID_HANDLE)
            {
                double atr_buffer[1];
                if(CopyBuffer(atr_handle, 0, 0, 1, atr_buffer) == 1)
                {
                    double atr_value = atr_buffer[0];
                    tp = entry_price - (atr_multiplier * atr_value);
                }
                IndicatorRelease(atr_handle);
            }
        }
        else if(tp_method == 1) // Fixed Risk:Reward ratio
        {
            double sl_distance_points = MathAbs(entry_price - sl_price) / point;
            tp = entry_price - (sl_distance_points * risk_reward_ratio * point);
        }
        
        // Apply stops level constraint
        double minDist = SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
        if(minDist <= 0) minDist = 10 * point;
        
        // For SELL, TP must be below entry - minDist
        tp = MathMin(tp, entry_price - minDist);
        tp = NormalizeDouble(tp, (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS));
        
        return tp;
    }
    
    // Calculate lot size based on risk
    double CalculateLotSize(double entry_price, double sl_price, int lot_method,
                           double risk_percent = 1.0, double fixed_lot = 0.01,
                           double min_lot = 0.01, double max_lot = 100.0)
    {
        double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
        double lot_raw = 0.0;
        
        if(lot_method == 0) // % of equity
        {
            double risk_money = AccountEquity() * (risk_percent / 100.0);
            double sl_distance_points = MathAbs(entry_price - sl_price) / point;
            double tick_value = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
            
            if(sl_distance_points > 0 && tick_value > 0)
            {
                lot_raw = risk_money / (sl_distance_points * point * tick_value);
            }
        }
        else if(lot_method == 1) // Fixed lot
        {
            lot_raw = fixed_lot;
        }
        
        // Apply lot size constraints
        double lot_step = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
        double lot = MathMax(min_lot, MathMin(max_lot, lot_raw));
        
        // Normalize to lot step
        if(lot_step > 0)
        {
            lot = MathRound(lot / lot_step) * lot_step;
        }
        
        // Round to 2 decimal places
        lot = NormalizeDouble(lot, 2);
        
        return lot;
    }
    
    // Check if price has broken above range high (for BUY STOP)
    bool IsBreakoutLong(double tolerance_pips = 0)
    {
        if(m_range_high <= 0.0) return false;
        
        double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
        double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
        return ask > m_range_high + tolerance_pips * point * 10;
    }
    
    // Check if price has broken below range low (for SELL STOP)
    bool IsBreakoutShort(double tolerance_pips = 0)
    {
        if(m_range_low <= 0.0) return false;
        
        double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
        double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
        return bid < m_range_low - tolerance_pips * point * 10;
    }
    
    // Check retest after breakout for LONG
    bool IsRetestLong(double tolerance_pips = 5)
    {
        if(m_range_high <= 0.0) return false;
        
        double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
        double tol = tolerance_pips * point * 10;
        
        // Get previous bar low and close
        double low_bar = iLow(m_symbol, PERIOD_CURRENT, 1);
        double close_bar = iClose(m_symbol, PERIOD_CURRENT, 1);
        
        return (low_bar <= m_range_high + tol && close_bar > m_range_high);
    }
    
    // Check retest after breakout for SHORT
    bool IsRetestShort(double tolerance_pips = 5)
    {
        if(m_range_low <= 0.0) return false;
        
        double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
        double tol = tolerance_pips * point * 10;
        
        // Get previous bar high and close
        double high_bar = iHigh(m_symbol, PERIOD_CURRENT, 1);
        double close_bar = iClose(m_symbol, PERIOD_CURRENT, 1);
        
        return (high_bar >= m_range_low - tol && close_bar < m_range_low);
    }
    
    // Get indicator value helper (from reference patterns)
    double GetIndicatorValue(int handle, int buffer_num, int shift)
    {
        double buffer[1];
        if(CopyBuffer(handle, buffer_num, shift, 1, buffer) == 1)
            return buffer[0];
        return 0.0;
    }
    
    // Check for new bar (from reference patterns)
    bool IsNewBar(ENUM_TIMEFRAMES tf)
    {
        static datetime lastBarTime = 0;
        datetime currentBar = iTime(m_symbol, tf, 0);
        if(lastBarTime != currentBar)
        {
            lastBarTime = currentBar;
            return true;
        }
        return false;
    }
    
    // Reset calculation (force recalculation)
    void Reset()
    {
        m_last_calc_time = 0;
        m_range_high = 0.0;
        m_range_low = 0.0;
    }
};