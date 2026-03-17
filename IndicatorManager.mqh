//+------------------------------------------------------------------+
//|                                                      IndicatorManager.mqh |
//|                        Copyright 2023, MetaQuotes Ltd.            |
//|                                             https://www.mql5.com  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Indicator Manager Class                                          |
//+------------------------------------------------------------------+
class CIndicatorManager
{
private:
   // Indicator handles
   int m_emaFastHandle;
   int m_emaSlowHandle;
   int m_adxHandle;
   int m_atrHandle;
   int m_bbHandle;
   int m_rsiHandle;
   
   // Configuration
   string m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   
   // Error tracking
   bool m_initialized;
   string m_lastError;
   
public:
   // Constructor
   CIndicatorManager() : m_symbol(_Symbol), 
                         m_timeframe(PERIOD_CURRENT),
                         m_initialized(false),
                         m_lastError("") 
   {
      m_emaFastHandle = INVALID_HANDLE;
      m_emaSlowHandle = INVALID_HANDLE;
      m_adxHandle = INVALID_HANDLE;
      m_atrHandle = INVALID_HANDLE;
      m_bbHandle = INVALID_HANDLE;
      m_rsiHandle = INVALID_HANDLE;
   }
   
   // Destructor
   ~CIndicatorManager()
   {
      ReleaseHandles();
   }
   
   // Initialization method
   bool Initialize(int emaFastPeriod = 9, 
                   int emaSlowPeriod = 21,
                   int adxPeriod = 14,
                   int atrPeriod = 14,
                   int bbPeriod = 20,
                   double bbDeviation = 2.0,
                   int rsiPeriod = 14,
                   ENUM_APPLIED_PRICE rsiAppliedPrice = PRICE_CLOSE)
   {
      // Release any existing handles
      ReleaseHandles();
      
      // Create EMA handles
      m_emaFastHandle = iMA(m_symbol, m_timeframe, emaFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
      if(m_emaFastHandle == INVALID_HANDLE)
      {
         m_lastError = "Failed to create fast EMA handle";
         return false;
      }
      
      m_emaSlowHandle = iMA(m_symbol, m_timeframe, emaSlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
      if(m_emaSlowHandle == INVALID_HANDLE)
      {
         m_lastError = "Failed to create slow EMA handle";
         ReleaseHandles();
         return false;
      }
      
      // Create ADX handle
      m_adxHandle = iADX(m_symbol, m_timeframe, adxPeriod);
      if(m_adxHandle == INVALID_HANDLE)
      {
         m_lastError = "Failed to create ADX handle";
         ReleaseHandles();
         return false;
      }
      
      // Create ATR handle
      m_atrHandle = iATR(m_symbol, m_timeframe, atrPeriod);
      if(m_atrHandle == INVALID_HANDLE)
      {
         m_lastError = "Failed to create ATR handle";
         ReleaseHandles();
         return false;
      }
      
      // Create Bollinger Bands handle
      m_bbHandle = iBands(m_symbol, m_timeframe, bbPeriod, 0, bbDeviation, PRICE_CLOSE);
      if(m_bbHandle == INVALID_HANDLE)
      {
         m_lastError = "Failed to create Bollinger Bands handle";
         ReleaseHandles();
         return false;
      }
      
      // Create RSI handle
      m_rsiHandle = iRSI(m_symbol, m_timeframe, rsiPeriod, rsiAppliedPrice);
      if(m_rsiHandle == INVALID_HANDLE)
      {
         m_lastError = "Failed to create RSI handle";
         ReleaseHandles();
         return false;
      }
      
      m_initialized = true;
      return true;
   }
   
   // Release all indicator handles
   void ReleaseHandles()
   {
      if(m_emaFastHandle != INVALID_HANDLE)
      {
         IndicatorRelease(m_emaFastHandle);
         m_emaFastHandle = INVALID_HANDLE;
      }
      
      if(m_emaSlowHandle != INVALID_HANDLE)
      {
         IndicatorRelease(m_emaSlowHandle);
         m_emaSlowHandle = INVALID_HANDLE;
      }
      
      if(m_adxHandle != INVALID_HANDLE)
      {
         IndicatorRelease(m_adxHandle);
         m_adxHandle = INVALID_HANDLE;
      }
      
      if(m_atrHandle != INVALID_HANDLE)
      {
         IndicatorRelease(m_atrHandle);
         m_atrHandle = INVALID_HANDLE;
      }
      
      if(m_bbHandle != INVALID_HANDLE)
      {
         IndicatorRelease(m_bbHandle);
         m_bbHandle = INVALID_HANDLE;
      }
      
      if(m_rsiHandle != INVALID_HANDLE)
      {
         IndicatorRelease(m_rsiHandle);
         m_rsiHandle = INVALID_HANDLE;
      }
      
      m_initialized = false;
   }
   
   // Check if manager is initialized
   bool IsInitialized() const { return m_initialized; }
   
   // Get last error message
   string GetLastError() const { return m_lastError; }
   
   // Set symbol and timeframe
   void SetSymbol(string symbol) { m_symbol = symbol; }
   void SetTimeframe(ENUM_TIMEFRAMES timeframe) { m_timeframe = timeframe; }
   
   //+------------------------------------------------------------------+
   //| Get indicator values                                             |
   //+------------------------------------------------------------------+
   
   // Generic function to get indicator value
   double GetIndicatorValue(int handle, int bufferNum, int shift = 0)
   {
      if(handle == INVALID_HANDLE)
      {
         m_lastError = "Invalid indicator handle";
         return EMPTY_VALUE;
      }
      
      double buffer[];
      ArraySetAsSeries(buffer, true);
      
      if(CopyBuffer(handle, bufferNum, shift, 1, buffer) <= 0)
      {
         m_lastError = "Failed to copy indicator buffer";
         return EMPTY_VALUE;
      }
      
      return buffer[0];
   }
   
   // Get EMA values
   double GetEMAFast(int shift = 0)
   {
      return GetIndicatorValue(m_emaFastHandle, 0, shift);
   }
   
   double GetEMASlow(int shift = 0)
   {
      return GetIndicatorValue(m_emaSlowHandle, 0, shift);
   }
   
   // Get ADX values (main, +DI, -DI)
   double GetADX(int shift = 0)
   {
      return GetIndicatorValue(m_adxHandle, 0, shift);
   }
   
   double GetADXPlusDI(int shift = 0)
   {
      return GetIndicatorValue(m_adxHandle, 1, shift);
   }
   
   double GetADXMinusDI(int shift = 0)
   {
      return GetIndicatorValue(m_adxHandle, 2, shift);
   }
   
   // Get ATR value
   double GetATR(int shift = 0)
   {
      return GetIndicatorValue(m_atrHandle, 0, shift);
   }
   
   // Get Bollinger Bands values (upper, middle, lower)
   double GetBBUpper(int shift = 0)
   {
      return GetIndicatorValue(m_bbHandle, 1, shift);
   }
   
   double GetBBMiddle(int shift = 0)
   {
      return GetIndicatorValue(m_bbHandle, 0, shift);
   }
   
   double GetBBLower(int shift = 0)
   {
      return GetIndicatorValue(m_bbHandle, 2, shift);
   }
   
   // Get RSI value
   double GetRSI(int shift = 0)
   {
      return GetIndicatorValue(m_rsiHandle, 0, shift);
   }
   
   //+------------------------------------------------------------------+
   //| Filtering functions                                              |
   //+------------------------------------------------------------------+
   
   // Check if trend is bullish (fast EMA above slow EMA)
   bool IsTrendBullish(int shift = 0)
   {
      double fast = GetEMAFast(shift);
      double slow = GetEMASlow(shift);
      
      if(fast == EMPTY_VALUE || slow == EMPTY_VALUE)
         return false;
         
      return fast > slow;
   }
   
   // Check if trend is bearish (fast EMA below slow EMA)
   bool IsTrendBearish(int shift = 0)
   {
      double fast = GetEMAFast(shift);
      double slow = GetEMASlow(shift);
      
      if(fast == EMPTY_VALUE || slow == EMPTY_VALUE)
         return false;
         
      return fast < slow;
   }
   
   // Check if ADX shows strong trend (above threshold)
   bool IsStrongTrend(int shift = 0, double threshold = 25.0)
   {
      double adx = GetADX(shift);
      
      if(adx == EMPTY_VALUE)
         return false;
         
      return adx > threshold;
   }
   
   // Check if +DI is above -DI (bullish momentum)
   bool IsBullishMomentum(int shift = 0)
   {
      double plusDI = GetADXPlusDI(shift);
      double minusDI = GetADXMinusDI(shift);
      
      if(plusDI == EMPTY_VALUE || minusDI == EMPTY_VALUE)
         return false;
         
      return plusDI > minusDI;
   }
   
   // Check if -DI is above +DI (bearish momentum)
   bool IsBearishMomentum(int shift = 0)
   {
      double plusDI = GetADXPlusDI(shift);
      double minusDI = GetADXMinusDI(shift);
      
      if(plusDI == EMPTY_VALUE || minusDI == EMPTY_VALUE)
         return false;
         
      return minusDI > plusDI;
   }
   
   // Check if price is above Bollinger Band middle line
   bool IsPriceAboveBBMiddle(int shift = 0)
   {
      double price = iClose(m_symbol, m_timeframe, shift);
      double bbMiddle = GetBBMiddle(shift);
      
      if(price == EMPTY_VALUE || bbMiddle == EMPTY_VALUE)
         return false;
         
      return price > bbMiddle;
   }
   
   // Check if price is below Bollinger Band middle line
   bool IsPriceBelowBBMiddle(int shift = 0)
   {
      double price = iClose(m_symbol, m_timeframe, shift);
      double bbMiddle = GetBBMiddle(shift);
      
      if(price == EMPTY_VALUE || bbMiddle == EMPTY_VALUE)
         return false;
         
      return price < bbMiddle;
   }
   
   // Check if price is near Bollinger Band upper band (within percentage)
   bool IsPriceNearBBUpper(int shift = 0, double percentage = 0.1)
   {
      double price = iClose(m_symbol, m_timeframe, shift);
      double bbUpper = GetBBUpper(shift);
      double bbMiddle = GetBBMiddle(shift);
      
      if(price == EMPTY_VALUE || bbUpper == EMPTY_VALUE || bbMiddle == EMPTY_VALUE)
         return false;
         
      double bandWidth = bbUpper - bbMiddle;
      if(bandWidth <= 0) return false;
      
      double distance = bbUpper - price;
      return (distance / bandWidth) <= (percentage / 100.0);
   }
   
   // Check if price is near Bollinger Band lower band (within percentage)
   bool IsPriceNearBBLower(int shift = 0, double percentage = 0.1)
   {
      double price = iClose(m_symbol, m_timeframe, shift);
      double bbLower = GetBBLower(shift);
      double bbMiddle = GetBBMiddle(shift);
      
      if(price == EMPTY_VALUE || bbLower == EMPTY_VALUE || bbMiddle == EMPTY_VALUE)
         return false;
         
      double bandWidth = bbMiddle - bbLower;
      if(bandWidth <= 0) return false;
      
      double distance = price - bbLower;
      return (distance / bandWidth) <= (percentage / 100.0);
   }
   
   // Check if RSI is overbought (above threshold)
   bool IsRSIOverbought(int shift = 0, double threshold = 70.0)
   {
      double rsi = GetRSI(shift);
      
      if(rsi == EMPTY_VALUE)
         return false;
         
      return rsi > threshold;
   }
   
   // Check if RSI is oversold (below threshold)
   bool IsRSIOversold(int shift = 0, double threshold = 30.0)
   {
      double rsi = GetRSI(shift);
      
      if(rsi == EMPTY_VALUE)
         return false;
         
      return rsi < threshold;
   }
   
   // Check if RSI is in neutral zone
   bool IsRSINeutral(int shift = 0, double lowerThreshold = 30.0, double upperThreshold = 70.0)
   {
      double rsi = GetRSI(shift);
      
      if(rsi == EMPTY_VALUE)
         return false;
         
      return rsi >= lowerThreshold && rsi <= upperThreshold;
   }
   
   //+------------------------------------------------------------------+
   //| Signal generation helpers                                        |
   //+------------------------------------------------------------------+
   
   // Check for EMA crossover (bullish)
   bool IsEMACrossoverBullish(int signalShift = 0)
   {
      double fast0 = GetEMAFast(signalShift);
      double slow0 = GetEMASlow(signalShift);
      double fast1 = GetEMAFast(signalShift + 1);
      double slow1 = GetEMASlow(signalShift + 1);
      
      if(fast0 == EMPTY_VALUE || slow0 == EMPTY_VALUE || 
         fast1 == EMPTY_VALUE || slow1 == EMPTY_VALUE)
         return false;
         
      return (fast1 <= slow1 && fast0 > slow0);
   }
   
   // Check for EMA crossover (bearish)
   bool IsEMACrossoverBearish(int signalShift = 0)
   {
      double fast0 = GetEMAFast(signalShift);
      double slow0 = GetEMASlow(signalShift);
      double fast1 = GetEMAFast(signalShift + 1);
      double slow1 = GetEMASlow(signalShift + 1);
      
      if(fast0 == EMPTY_VALUE || slow0 == EMPTY_VALUE || 
         fast1 == EMPTY_VALUE || slow1 == EMPTY_VALUE)
         return false;
         
      return (fast1 >= slow1 && fast0 < slow0);
   }
   
   // Get volatility multiplier based on ATR
   double GetVolatilityMultiplier(int shift = 0, double baseMultiplier = 1.0)
   {
      double atr = GetATR(shift);
      double price = iClose(m_symbol, m_timeframe, shift);
      
      if(atr == EMPTY_VALUE || price == EMPTY_VALUE || price == 0)
         return baseMultiplier;
         
      // Calculate ATR as percentage of price
      double atrPercent = (atr / price) * 100.0;
      
      // Adjust multiplier based on volatility
      // Higher volatility = smaller multiplier, lower volatility = larger multiplier
      if(atrPercent > 1.5) return baseMultiplier * 0.7;      // High volatility
      else if(atrPercent < 0.5) return baseMultiplier * 1.3; // Low volatility
      else return baseMultiplier;                            // Normal volatility
   }
   
   // Get current market condition summary
   string GetMarketCondition(int shift = 0)
   {
      string condition = "";
      
      // Trend condition
      if(IsTrendBullish(shift))
         condition += "Bullish Trend | ";
      else if(IsTrendBearish(shift))
         condition += "Bearish Trend | ";
      else
         condition += "Sideways | ";
      
      // ADX strength
      if(IsStrongTrend(shift))
         condition += "Strong Trend | ";
      else
         condition += "Weak Trend | ";
      
      // RSI condition
      if(IsRSIOverbought(shift))
         condition += "RSI Overbought | ";
      else if(IsRSIOversold(shift))
         condition += "RSI Oversold | ";
      else
         condition += "RSI Neutral | ";
      
      // Bollinger Band position
      if(IsPriceNearBBUpper(shift))
         condition += "Near BB Upper";
      else if(IsPriceNearBBLower(shift))
         condition += "Near BB Lower";
      else if(IsPriceAboveBBMiddle(shift))
         condition += "Above BB Middle";
      else
         condition += "Below BB Middle";
      
      return condition;
   }
};
//+------------------------------------------------------------------+