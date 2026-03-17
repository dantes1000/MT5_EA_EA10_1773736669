//+------------------------------------------------------------------+
//|                                                      TimeFilter.mqh |
//|                        Copyright 2023, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Time Filter Class                                                |
//+------------------------------------------------------------------+
class CTimeFilter
{
private:
   // Configuration parameters
   bool      m_enableSessionFilter;      // Enable trading session filter
   string    m_sessionStart;             // Session start time (HH:MM)
   string    m_sessionEnd;               // Session end time (HH:MM)
   bool      m_enableWeekdayFilter;      // Enable weekday filter
   int       m_allowedWeekdays[7];       // Array of allowed weekdays (0=Sunday, 1=Monday, ..., 6=Saturday)
   int       m_weekdayCount;             // Number of allowed weekdays
   bool      m_enableNewsFilter;         // Enable news impact window avoidance
   int       m_newsWindowBefore;         // Minutes before news to avoid
   int       m_newsWindowAfter;          // Minutes after news to avoid
   
   // Internal state
   datetime  m_lastNewsCheck;            // Last time news data was checked
   datetime  m_newsStartTime;            // Start time of next news event
   datetime  m_newsEndTime;              // End time of next news event
   string    m_newsCurrency;             // Currency affected by news
   
public:
   // Constructor
   CTimeFilter()
   {
      m_enableSessionFilter = false;
      m_sessionStart = "00:00";
      m_sessionEnd = "23:59";
      m_enableWeekdayFilter = false;
      m_weekdayCount = 0;
      m_enableNewsFilter = false;
      m_newsWindowBefore = 30;
      m_newsWindowAfter = 30;
      m_lastNewsCheck = 0;
      m_newsStartTime = 0;
      m_newsEndTime = 0;
      m_newsCurrency = "";
   }
   
   // Destructor
   ~CTimeFilter() {}
   
   // Set trading session filter
   void SetSessionFilter(bool enable, string startTime="00:00", string endTime="23:59")
   {
      m_enableSessionFilter = enable;
      m_sessionStart = startTime;
      m_sessionEnd = endTime;
   }
   
   // Set weekday filter
   void SetWeekdayFilter(bool enable, int &weekdays[])
   {
      m_enableWeekdayFilter = enable;
      m_weekdayCount = ArraySize(weekdays);
      ArrayCopy(m_allowedWeekdays, weekdays);
   }
   
   // Set news filter
   void SetNewsFilter(bool enable, int minutesBefore=30, int minutesAfter=30)
   {
      m_enableNewsFilter = enable;
      m_newsWindowBefore = minutesBefore;
      m_newsWindowAfter = minutesAfter;
   }
   
   // Check if trading is allowed based on all filters
   bool IsTradingAllowed()
   {
      // Check session filter
      if(m_enableSessionFilter && !IsInTradingSession())
         return false;
      
      // Check weekday filter
      if(m_enableWeekdayFilter && !IsAllowedWeekday())
         return false;
      
      // Check news filter
      if(m_enableNewsFilter && IsInNewsWindow())
         return false;
      
      return true;
   }
   
   // Check if current time is within trading session
   bool IsInTradingSession()
   {
      datetime currentTime = TimeCurrent();
      
      // Parse session times
      datetime sessionStart = StringToTime(TimeToString(currentTime, TIME_DATE) + " " + m_sessionStart);
      datetime sessionEnd = StringToTime(TimeToString(currentTime, TIME_DATE) + " " + m_sessionEnd);
      
      // Handle overnight sessions
      if(sessionEnd < sessionStart)
         sessionEnd += 86400; // Add one day
      
      return (currentTime >= sessionStart && currentTime <= sessionEnd);
   }
   
   // Check if current weekday is allowed
   bool IsAllowedWeekday()
   {
      int currentWeekday = TimeDayOfWeek(TimeCurrent());
      
      for(int i = 0; i < m_weekdayCount; i++)
      {
         if(m_allowedWeekdays[i] == currentWeekday)
            return true;
      }
      
      return false;
   }
   
   // Check if current time is within news impact window
   bool IsInNewsWindow()
   {
      // Update news data if needed (check every 5 minutes)
      if(TimeCurrent() - m_lastNewsCheck > 300)
         UpdateNewsData();
      
      // If no upcoming news, trading is allowed
      if(m_newsStartTime == 0)
         return false;
      
      datetime currentTime = TimeCurrent();
      datetime windowStart = m_newsStartTime - (m_newsWindowBefore * 60);
      datetime windowEnd = m_newsEndTime + (m_newsWindowAfter * 60);
      
      return (currentTime >= windowStart && currentTime <= windowEnd);
   }
   
   // Update news data (simplified - in real implementation, connect to news feed)
   void UpdateNewsData()
   {
      m_lastNewsCheck = TimeCurrent();
      
      // This is a simplified implementation
      // In a real EA, you would connect to a news feed or calendar API
      // For demonstration, we'll simulate finding the next news event
      
      // Get current symbol's base and quote currencies
      string symbol = Symbol();
      string baseCurrency = StringSubstr(symbol, 0, 3);
      string quoteCurrency = StringSubstr(symbol, 3, 3);
      
      // Check if there's a news event in the next 24 hours for these currencies
      // This would normally come from an external data source
      m_newsStartTime = 0;
      m_newsEndTime = 0;
      m_newsCurrency = "";
      
      // Example: Simulate finding a news event at 14:30 today for USD
      datetime today = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
      datetime newsTime = today + (14 * 3600) + (30 * 60); // 14:30
      
      if(TimeCurrent() < newsTime && newsTime < TimeCurrent() + 86400)
      {
         // Check if news affects our currency pair
         if(baseCurrency == "USD" || quoteCurrency == "USD")
         {
            m_newsStartTime = newsTime;
            m_newsEndTime = newsTime + 1800; // 30 minute event
            m_newsCurrency = "USD";
         }
      }
   }
   
   // Get time until next allowed trading period (in seconds)
   int TimeUntilTradingAllowed()
   {
      if(IsTradingAllowed())
         return 0;
      
      datetime currentTime = TimeCurrent();
      datetime nextAllowedTime = 0;
      
      // Calculate next allowed time based on filters
      if(m_enableSessionFilter && !IsInTradingSession())
      {
         datetime sessionStart = StringToTime(TimeToString(currentTime, TIME_DATE) + " " + m_sessionStart);
         if(currentTime > sessionStart)
            sessionStart += 86400; // Next day
         
         if(nextAllowedTime == 0 || sessionStart < nextAllowedTime)
            nextAllowedTime = sessionStart;
      }
      
      if(m_enableWeekdayFilter && !IsAllowedWeekday())
      {
         // Find next allowed weekday
         datetime nextWeekday = currentTime;
         for(int i = 1; i <= 7; i++)
         {
            nextWeekday += 86400;
            int weekday = TimeDayOfWeek(nextWeekday);
            
            for(int j = 0; j < m_weekdayCount; j++)
            {
               if(m_allowedWeekdays[j] == weekday)
               {
                  // Set to start of that day
                  nextWeekday = StringToTime(TimeToString(nextWeekday, TIME_DATE) + " 00:00");
                  if(nextAllowedTime == 0 || nextWeekday < nextAllowedTime)
                     nextAllowedTime = nextWeekday;
                  break;
               }
            }
         }
      }
      
      if(m_enableNewsFilter && IsInNewsWindow())
      {
         datetime newsEnd = m_newsEndTime + (m_newsWindowAfter * 60);
         if(nextAllowedTime == 0 || newsEnd < nextAllowedTime)
            nextAllowedTime = newsEnd;
      }
      
      if(nextAllowedTime > 0)
         return (int)(nextAllowedTime - currentTime);
      
      return 0;
   }
   
   // Get filter status as string for logging
   string GetFilterStatus()
   {
      string status = "Time Filter Status:\n";
      
      if(m_enableSessionFilter)
      {
         status += "Session Filter: " + (IsInTradingSession() ? "PASS" : "FAIL") + "\n";
         status += "  Session: " + m_sessionStart + " - " + m_sessionEnd + "\n";
      }
      
      if(m_enableWeekdayFilter)
      {
         status += "Weekday Filter: " + (IsAllowedWeekday() ? "PASS" : "FAIL") + "\n";
         status += "  Allowed Days: ";
         for(int i = 0; i < m_weekdayCount; i++)
         {
            switch(m_allowedWeekdays[i])
            {
               case 0: status += "Sun "; break;
               case 1: status += "Mon "; break;
               case 2: status += "Tue "; break;
               case 3: status += "Wed "; break;
               case 4: status += "Thu "; break;
               case 5: status += "Fri "; break;
               case 6: status += "Sat "; break;
            }
         }
         status += "\n";
      }
      
      if(m_enableNewsFilter)
      {
         status += "News Filter: " + (!IsInNewsWindow() ? "PASS" : "FAIL") + "\n";
         if(m_newsStartTime > 0)
         {
            status += "  Next News: " + TimeToString(m_newsStartTime) + " (" + m_newsCurrency + ")\n";
            status += "  Avoid: " + IntegerToString(m_newsWindowBefore) + "m before, " + 
                      IntegerToString(m_newsWindowAfter) + "m after\n";
         }
      }
      
      return status;
   }
};

//+------------------------------------------------------------------+
//| Helper Functions                                                 |
//+------------------------------------------------------------------+

// Check if new bar has formed
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

// Calculate lot size based on risk percentage
double CalcLotSize(double entryPrice, double stopLossPrice, double riskPercent, double minLot, double maxLot)
{
   // Respect SYMBOL_TRADE_STOPS_LEVEL
   double minDist = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   if(minDist <= 0) minDist = 10 * _Point;
   
   // Normalize prices
   entryPrice = NormalizeDouble(entryPrice, _Digits);
   stopLossPrice = NormalizeDouble(stopLossPrice, _Digits);
   
   // Calculate SL distance in points
   double slDistancePoints = MathAbs(entryPrice - stopLossPrice) / _Point;
   
   // Calculate risk money
   double riskMoney = AccountEquity() * (riskPercent / 100.0);
   
   // Get tick value
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   
   // Calculate raw lot size
   double lotRaw = riskMoney / (slDistancePoints * _Point * tickValue);
   
   // Apply lot limits and normalize
   double lot = MathMax(minLot, MathMin(maxLot, NormalizeDouble(lotRaw, 2)));
   
   return lot;
}

// Get indicator value safely
double GetIndicatorValue(int handle, int bufferIndex, int shift)
{
   double value[1];
   if(CopyBuffer(handle, bufferIndex, shift, 1, value) == 1)
      return value[0];
   return 0.0;
}

//+------------------------------------------------------------------+
