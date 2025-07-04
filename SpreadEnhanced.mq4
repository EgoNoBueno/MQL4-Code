//+------------------------------------------------------------------+
//|                                              Spread_Enhanced.mq4 |
//|                                           Copyright © 2024       |
//|                                          by: EgoNoBueno          |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2024"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_color1  clrRed

//--- input parameters for original Spread display (as used by original OnCalculate)
extern int XOffset = 600;    // Horizontal offset for Spread in pixels
extern int YOffset = 20;     // Vertical offset for Spread text (top of the first line)
extern color TextColor = clrRed; // Color of the Spread text
extern int TextSize = 18;        // Size of the Spread text

//--- input parameters for Day of Week display
extern int XOffset_Day = 600;    // Horizontal offset for Day of Week text
extern color TextColor_Day = clrGreen; // Color for Day of Week text
extern int TextSize_Day = 10;        // Size for Day of Week text

//--- input parameters for Time Left on Candle display
extern int XOffset_TimeLeft = 600; // Horizontal offset for Time Left text
extern color TextColor_TimeLeft = clrBlue; // Color for Time Left text
extern int TextSize_TimeLeft = 10;     // Size for Time Left text

//--- input parameter for row spacing
extern int RowSpacing = 15;       // Additional vertical pixels between text rows

// Object names
string dayOfWeekLabelName = "DayOfWeekText_Indicator";
string timeLeftLabelName = "TimeLeftText_Indicator";
// The original OnCalculate uses "SpreadText" directly.

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Calculate Y positions for the labels
   // YOffset is the top of the Spread text. TextSize is its font size.
   // The next label (Day of Week) will start below the Spread text.
   int yPos_Day = YOffset + TextSize + RowSpacing; 
   
   // The Time Left label will start below the Day of Week text.
   int yPos_TimeLeft = yPos_Day + TextSize_Day + RowSpacing;

//--- Create Day of Week Label
   ObjectCreate(0, dayOfWeekLabelName, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, dayOfWeekLabelName, OBJPROP_XDISTANCE, XOffset_Day);
   ObjectSetInteger(0, dayOfWeekLabelName, OBJPROP_YDISTANCE, yPos_Day); // Use calculated Y
   ObjectSetInteger(0, dayOfWeekLabelName, OBJPROP_COLOR, TextColor_Day);
   ObjectSetInteger(0, dayOfWeekLabelName, OBJPROP_FONTSIZE, TextSize_Day);
   ObjectSetString(0, dayOfWeekLabelName, OBJPROP_TEXT, "Day: Loading...");
   ObjectSetInteger(0, dayOfWeekLabelName, OBJPROP_SELECTABLE, false);

//--- Create Time Left Label
   ObjectCreate(0, timeLeftLabelName, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, timeLeftLabelName, OBJPROP_XDISTANCE, XOffset_TimeLeft);
   ObjectSetInteger(0, timeLeftLabelName, OBJPROP_YDISTANCE, yPos_TimeLeft); // Use calculated Y
   ObjectSetInteger(0, timeLeftLabelName, OBJPROP_COLOR, TextColor_TimeLeft);
   ObjectSetInteger(0, timeLeftLabelName, OBJPROP_FONTSIZE, TextSize_TimeLeft);
   ObjectSetString(0, timeLeftLabelName, OBJPROP_TEXT, "Candle Time Left: Loading...");
   ObjectSetInteger(0, timeLeftLabelName, OBJPROP_SELECTABLE, false);

//--- Set timer to update every 1 second
   EventSetTimer(1);
   
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- Kill timer
   EventKillTimer();
   
//--- Delete custom objects
   ObjectDelete(0, dayOfWeekLabelName);
   ObjectDelete(0, timeLeftLabelName);
   
//--- Delete object created by original OnCalculate (as per original OnDeinit)
   ObjectDelete("SpreadText"); 
  }

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
//--- Display Day of Week
   string dayString = "";
   int day = DayOfWeek(); 

   switch(day)
     {
      case 0: dayString = "Sunday"; break;
      case 1: dayString = "Monday"; break;
      case 2: dayString = "Tuesday"; break;
      case 3: dayString = "Wednesday"; break;
      case 4: dayString = "Thursday"; break;
      case 5: dayString = "Friday"; break;
      case 6: dayString = "Saturday"; break;
      default: dayString = "Unknown";
     }
   ObjectSetString(0, dayOfWeekLabelName, OBJPROP_TEXT, "Day: " + dayString);

//--- Display Time Left On Current Candle
   long periodSeconds = PeriodSeconds(Period());
   if(periodSeconds == 0) 
     {
      ObjectSetString(0, timeLeftLabelName, OBJPROP_TEXT, "Candle Time Left: N/A");
      return;
     }
     
   datetime currentTime = TimeCurrent(); 
   datetime barOpenTime = iTime(Symbol(), Period(), 0); 
   long secondsElapsedOnCurrentBar = currentTime - barOpenTime;
   long secondsLeft = periodSeconds - (secondsElapsedOnCurrentBar % periodSeconds);

   if(secondsLeft > periodSeconds || secondsLeft < 0) secondsLeft = 0; 

   long minutesLeft = secondsLeft / 60;
   long secsRemain = secondsLeft % 60;
   
   string timeLeftStr = StringFormat("Candle Time Left: %02d:%02d", minutesLeft, secsRemain);
   ObjectSetString(0, timeLeftLabelName, OBJPROP_TEXT, timeLeftStr);
  }

//+------------------------------------------------------------------+
//| OnCalculate - THIS IS THE ORIGINAL FUNCTION FROM SPREAD.TXT      |
//| IT HAS NOT BEEN MODIFIED.                                        |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
//---
   double   spreadValue;
   color  textColorValue;
   int    chartWidth; 

//get the spread value.
   spreadValue = Ask-Bid; 
   if(spreadValue < 0)
      spreadValue = 0;

   textColorValue = TextColor; 

//--- Draw the spread text on the chart
   ObjectDelete("SpreadText"); 
   ObjectCreate(0, "SpreadText", OBJ_LABEL, 0, 0, 0);


   chartWidth = 400;


   ObjectSetInteger(0, "SpreadText", OBJPROP_XDISTANCE, XOffset);  
   ObjectSetInteger(0, "SpreadText", OBJPROP_YDISTANCE, YOffset);  
   ObjectSetInteger(0, "SpreadText", OBJPROP_COLOR, textColorValue);
   ObjectSetInteger(0, "SpreadText", OBJPROP_FONTSIZE, TextSize);  
   ObjectSetString(0, "SpreadText", OBJPROP_TEXT, "Spread: " + DoubleToString(spreadValue, Digits())); // Using DoubleToString with Digits for precision


//---
   return(rates_total);
  }
//+------------------------------------------------------------------+