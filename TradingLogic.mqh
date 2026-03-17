#property strict

// TradingLogic.mqh - Complete implementation of entry conditions with trend, indicator, volume, and range breakout filters

class CTradingLogic
{
private:
    // Configuration parameters
    double m_marginPips;          // Margin for SL calculation (default: 5)
    int m_tpMethod;               // 0=ATR, 1=Fixed R:R
    double m_atrTpMult;           // ATR multiplier for TP
    double m_riskRewardRatio;     // R:R ratio for fixed TP
    int m_lotMethod;              // 0=% of equity, 1=Fixed lot
    double m_riskPercent;         // Risk % for equity method
    double m_fixedLot;            // Fixed lot size
    double m_minLot;              // Minimum lot size
    double m_maxLot;              // Maximum lot size
    int m_atrPeriod;              // ATR period for TP calculation
    double m_retestTolerancePips; // Retest tolerance in pips
    int m_signalShift;           // Signal shift for indicators
    
    // Internal state
    datetime m_lastBarTime;
    
    // Indicator handles
    int m_maFastHandle;
    int m_maSlowHandle;
    int m_atrHandle;
    
    // Helper functions
    double GetIndicatorValue(int handle, int buffer, int shift)
    {
        double value[1];
        if(CopyBuffer(handle, buffer, shift, 1, value) == 1)
            return value[0];
        return 0.0;
    }
    
    double NormalizePrice(double price)
    {
        return NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
    }
    
    double CalculateAsianRangeHigh()
    {
        double high = 0;
        datetime currentTime = TimeCurrent();
        datetime dayStart = iTime(_Symbol, PERIOD_D1, 0);
        
        for(int i = 0; i < 24; i++) // Check last 24 D1 bars
        {
            datetime barTime = iTime(_Symbol, PERIOD_D1, i);
            if(barTime == 0) break;
            
            // Check if bar is from current day and within Asian session (00:00-06:00 GMT)
            MqlDateTime dt;
            TimeToStruct(barTime, dt);
            
            if(dt.hour >= 0 && dt.hour < 6)
            {
                double barHigh = iHigh(_Symbol, PERIOD_D1, i);
                if(barHigh > high || high == 0)
                    high = barHigh;
            }
        }
        
        return high;
    }
    
    double CalculateAsianRangeLow()
    {
        double low = 0;
        datetime currentTime = TimeCurrent();
        datetime dayStart = iTime(_Symbol, PERIOD_D1, 0);
        
        for(int i = 0; i < 24; i++) // Check last 24 D1 bars
        {
            datetime barTime = iTime(_Symbol, PERIOD_D1, i);
            if(barTime == 0) break;
            
            // Check if bar is from current day and within Asian session (00:00-06:00 GMT)
            MqlDateTime dt;
            TimeToStruct(barTime, dt);
            
            if(dt.hour >= 0 && dt.hour < 6)
            {
                double barLow = iLow(_Symbol, PERIOD_D1, i);
                if(barLow < low || low == 0)
                    low = barLow;
            }
        }
        
        return low;
    }
    
    double CalculateStopLossLong(double entryPrice)
    {
        double rangeLow = CalculateAsianRangeLow();
        double margin = m_marginPips * _Point * 10; // Convert pips to points
        double sl = rangeLow - margin;
        
        // Apply SYMBOL_TRADE_STOPS_LEVEL constraint
        double minDist = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
        if(minDist <= 0) minDist = 10 * _Point;
        
        sl = MathMin(sl, entryPrice - minDist);
        return NormalizePrice(sl);
    }
    
    double CalculateStopLossShort(double entryPrice)
    {
        double rangeHigh = CalculateAsianRangeHigh();
        double margin = m_marginPips * _Point * 10; // Convert pips to points
        double sl = rangeHigh + margin;
        
        // Apply SYMBOL_TRADE_STOPS_LEVEL constraint
        double minDist = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
        if(minDist <= 0) minDist = 10 * _Point;
        
        sl = MathMax(sl, entryPrice + minDist);
        return NormalizePrice(sl);
    }
    
    double CalculateTakeProfitLong(double entryPrice, double slPrice)
    {
        double tp = 0;
        
        if(m_tpMethod == 0) // ATR method
        {
            double atrValue = GetIndicatorValue(m_atrHandle, 0, 0);
            tp = entryPrice + (m_atrTpMult * atrValue);
        }
        else if(m_tpMethod == 1) // Fixed R:R method
        {
            double slDistancePoints = MathAbs(entryPrice - slPrice) / _Point;
            tp = entryPrice + (slDistancePoints * m_riskRewardRatio * _Point);
        }
        
        // Apply SYMBOL_TRADE_STOPS_LEVEL constraint
        double minDist = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
        if(minDist <= 0) minDist = 10 * _Point;
        
        tp = MathMax(tp, entryPrice + minDist);
        return NormalizePrice(tp);
    }
    
    double CalculateTakeProfitShort(double entryPrice, double slPrice)
    {
        double tp = 0;
        
        if(m_tpMethod == 0) // ATR method
        {
            double atrValue = GetIndicatorValue(m_atrHandle, 0, 0);
            tp = entryPrice - (m_atrTpMult * atrValue);
        }
        else if(m_tpMethod == 1) // Fixed R:R method
        {
            double slDistancePoints = MathAbs(entryPrice - slPrice) / _Point;
            tp = entryPrice - (slDistancePoints * m_riskRewardRatio * _Point);
        }
        
        // Apply SYMBOL_TRADE_STOPS_LEVEL constraint
        double minDist = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
        if(minDist <= 0) minDist = 10 * _Point;
        
        tp = MathMin(tp, entryPrice - minDist);
        return NormalizePrice(tp);
    }
    
    double CalculateLotSize(double entryPrice, double slPrice)
    {
        double lotRaw = 0;
        
        if(m_lotMethod == 0) // % of equity
        {
            double riskMoney = AccountInfoDouble(ACCOUNT_EQUITY) * (m_riskPercent / 100.0);
            double slDistancePoints = MathAbs(entryPrice - slPrice) / _Point;
            double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
            
            if(slDistancePoints > 0 && tickValue > 0)
            {
                lotRaw = riskMoney / (slDistancePoints * _Point * tickValue);
            }
        }
        else if(m_lotMethod == 1) // Fixed lot
        {
            lotRaw = m_fixedLot;
        }
        
        // Apply lot size constraints
        double lot = MathMax(m_minLot, MathMin(m_maxLot, NormalizeDouble(lotRaw, 2)));
        return lot;
    }
    
public:
    CTradingLogic() :
        m_marginPips(5),
        m_tpMethod(0),
        m_atrTpMult(3.0),
        m_riskRewardRatio(1.5),
        m_lotMethod(0),
        m_riskPercent(2.0),
        m_fixedLot(0.01),
        m_minLot(0.01),
        m_maxLot(100.0),
        m_atrPeriod(14),
        m_retestTolerancePips(2),
        m_signalShift(0),
        m_lastBarTime(0),
        m_maFastHandle(INVALID_HANDLE),
        m_maSlowHandle(INVALID_HANDLE),
        m_atrHandle(INVALID_HANDLE)
    {
    }
    
    ~CTradingLogic()
    {
        if(m_maFastHandle != INVALID_HANDLE)
            IndicatorRelease(m_maFastHandle);
        if(m_maSlowHandle != INVALID_HANDLE)
            IndicatorRelease(m_maSlowHandle);
        if(m_atrHandle != INVALID_HANDLE)
            IndicatorRelease(m_atrHandle);
    }
    
    bool Initialize()
    {
        // Create indicator handles
        m_maFastHandle = iMA(_Symbol, PERIOD_H1, 10, 0, MODE_SMA, PRICE_CLOSE);
        m_maSlowHandle = iMA(_Symbol, PERIOD_H1, 20, 0, MODE_SMA, PRICE_CLOSE);
        m_atrHandle = iATR(_Symbol, PERIOD_H1, m_atrPeriod);
        
        return (m_maFastHandle != INVALID_HANDLE && 
                m_maSlowHandle != INVALID_HANDLE && 
                m_atrHandle != INVALID_HANDLE);
    }
    
    // Configuration setters
    void SetMarginPips(double marginPips) { m_marginPips = marginPips; }
    void SetTpMethod(int method) { m_tpMethod = method; }
    void SetAtrTpMult(double mult) { m_atrTpMult = mult; }
    void SetRiskRewardRatio(double ratio) { m_riskRewardRatio = ratio; }
    void SetLotMethod(int method) { m_lotMethod = method; }
    void SetRiskPercent(double percent) { m_riskPercent = percent; }
    void SetFixedLot(double lot) { m_fixedLot = lot; }
    void SetMinLot(double minLot) { m_minLot = minLot; }
    void SetMaxLot(double maxLot) { m_maxLot = maxLot; }
    void SetAtrPeriod(int period) { m_atrPeriod = period; }
    void SetRetestTolerancePips(double tolerance) { m_retestTolerancePips = tolerance; }
    void SetSignalShift(int shift) { m_signalShift = shift; }
    
    // New bar detection
    bool IsNewBar(ENUM_TIMEFRAMES tf)
    {
        datetime currentBar = iTime(_Symbol, tf, 0);
        if(m_lastBarTime != currentBar)
        {
            m_lastBarTime = currentBar;
            return true;
        }
        return false;
    }
    
    // Breakout entry conditions
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
    bool IsRetestLong(double level)
    {
        double point   = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        double tol     = m_retestTolerancePips * point * 10;
        double lowBar  = iLow(_Symbol, PERIOD_CURRENT, 1);
        double closeBar = iClose(_Symbol, PERIOD_CURRENT, 1);
        return (lowBar <= level + tol && closeBar > level);
    }
    
    bool IsRetestShort(double level)
    {
        double point    = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        double tol      = m_retestTolerancePips * point * 10;
        double highBar  = iHigh(_Symbol, PERIOD_CURRENT, 1);
        double closeBar = iClose(_Symbol, PERIOD_CURRENT, 1);
        return (highBar >= level - tol && closeBar < level);
    }
    
    // Trend entry (MA crossover)
    bool IsTrendLong()
    {
        double fast0 = GetIndicatorValue(m_maFastHandle, 0, m_signalShift);
        double slow0 = GetIndicatorValue(m_maSlowHandle, 0, m_signalShift);
        double fast1 = GetIndicatorValue(m_maFastHandle, 0, m_signalShift + 1);
        double slow1 = GetIndicatorValue(m_maSlowHandle, 0, m_signalShift + 1);
        return (fast1 <= slow1 && fast0 > slow0);
    }
    
    bool IsTrendShort()
    {
        double fast0 = GetIndicatorValue(m_maFastHandle, 0, m_signalShift);
        double slow0 = GetIndicatorValue(m_maSlowHandle, 0, m_signalShift);
        double fast1 = GetIndicatorValue(m_maFastHandle, 0, m_signalShift + 1);
        double slow1 = GetIndicatorValue(m_maSlowHandle, 0, m_signalShift + 1);
        return (fast1 >= slow1 && fast0 < slow0);
    }
    
    // Volume filter
    bool IsVolumeAboveAverage(int period = 20)
    {
        double currentVolume = (double)iVolume(_Symbol, PERIOD_CURRENT, 0);
        double sumVolume = 0;
        
        for(int i = 1; i <= period; i++)
        {
            sumVolume += (double)iVolume(_Symbol, PERIOD_CURRENT, i);
        }
        
        double avgVolume = sumVolume / period;
        return currentVolume > avgVolume * 1.2; // 20% above average
    }
    
    // Range breakout filter
    bool IsRangeBreakoutLong()
    {
        double rangeHigh = CalculateAsianRangeHigh();
        return IsBreakoutLong(rangeHigh) && IsRetestLong(rangeHigh);
    }
    
    bool IsRangeBreakoutShort()
    {
        double rangeLow = CalculateAsianRangeLow();
        return IsBreakoutShort(rangeLow) && IsRetestShort(rangeLow);
    }
    
    // Combined entry signal
    bool GetLongSignal()
    {
        return IsTrendLong() && 
               IsVolumeAboveAverage() && 
               IsRangeBreakoutLong();
    }
    
    bool GetShortSignal()
    {
        return IsTrendShort() && 
               IsVolumeAboveAverage() && 
               IsRangeBreakoutShort();
    }
    
    // Trade calculation methods
    bool CalculateLongTrade(double &entryPrice, double &slPrice, double &tpPrice, double &lotSize)
    {
        if(!GetLongSignal())
            return false;
        
        entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        slPrice = CalculateStopLossLong(entryPrice);
        tpPrice = CalculateTakeProfitLong(entryPrice, slPrice);
        lotSize = CalculateLotSize(entryPrice, slPrice);
        
        return true;
    }
    
    bool CalculateShortTrade(double &entryPrice, double &slPrice, double &tpPrice, double &lotSize)
    {
        if(!GetShortSignal())
            return false;
        
        entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        slPrice = CalculateStopLossShort(entryPrice);
        tpPrice = CalculateTakeProfitShort(entryPrice, slPrice);
        lotSize = CalculateLotSize(entryPrice, slPrice);
        
        return true;
    }
    
    // Get current Asian range levels
    double GetAsianRangeHigh() { return CalculateAsianRangeHigh(); }
    double GetAsianRangeLow() { return CalculateAsianRangeLow(); }
    
    // Get current indicator values
    double GetFastMA() { return GetIndicatorValue(m_maFastHandle, 0, 0); }
    double GetSlowMA() { return GetIndicatorValue(m_maSlowHandle, 0, 0); }
    double GetATR() { return GetIndicatorValue(m_atrHandle, 0, 0); }
};
