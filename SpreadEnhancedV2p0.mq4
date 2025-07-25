//+------------------------------------------------------------------+
//|                                         Spread_Enhanced V2p0.mq4 |
//|                                            Copyright © 2024      |
//|                                          by: EgoNoBueno          |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2025, EgoNoBueno"
#property version "2.0"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_color1  clrRed

//--- input parameters for original Spread display (as used by original OnCalculate)
extern int XOffset = 600;     // Horizontal offset for Spread in pixels
extern int YOffset = 20;      // Vertical offset for Spread text (top of the first line)
extern color TextColor = clrRed; // Color of the Spread text
extern int TextSize = 18;         // Size of the Spread text

//--- input parameters for Day of Week display
extern int XOffset_Day = 600;    // Horizontal offset for Day of Week text
extern color TextColor_Day = clrGreen; // Color for Day of Week text
extern int TextSize_Day = 12;         // Size for Day of Week text

//--- input parameters for Time Left on Candle display
extern int XOffset_TimeLeft = 600; // Horizontal offset for Time Left text
extern color TextColor_TimeLeft = clrBlue; // Color for Time Left text
extern int TextSize_TimeLeft = 12;      // Size for Time Left text

//--- NEW: input parameters for Time Period display
extern int XOffset_Period = 600;   // Horizontal offset for Time Period text
extern color TextColor_Period = clrMagenta; // Color for Time Period text
extern int TextSize_Period = 12;        // Size for Time Period text

//--- NEW: input parameters for Instrument display
extern int XOffset_Instrument = 600; // Horizontal offset for Instrument text
extern color TextColor_Instrument = clrRed; // Color for Instrument text
extern int TextSize_Instrument = 12;      // Size for Instrument text

//--- input parameter for row spacing
extern int RowSpacing = 15;         // Additional vertical pixels between text rows

// Object names
string dayOfWeekLabelName = "DayOfWeekText_Indicator";
string timeLeftLabelName = "TimeLeftText_Indicator";
string periodLabelName = "TimePeriodText_Indicator";     // NEW: Object name for Time Period label
string instrumentLabelName = "InstrumentText_Indicator"; // NEW: Object name for Instrument label
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

// NEW: Calculate Y position for Time Period label
   int yPos_Period = yPos_TimeLeft + TextSize_TimeLeft + RowSpacing;

// NEW: Calculate Y position for Instrument label
   int yPos_Instrument = yPos_Period + TextSize_Period + RowSpacing;

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

//--- NEW: Create Time Period Label
   ObjectCreate(0, periodLabelName, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, periodLabelName, OBJPROP_XDISTANCE, XOffset_Period);
   ObjectSetInteger(0, periodLabelName, OBJPROP_YDISTANCE, yPos_Period); // Use calculated Y
   ObjectSetInteger(0, periodLabelName, OBJPROP_COLOR, TextColor_Period);
   ObjectSetInteger(0, periodLabelName, OBJPROP_FONTSIZE, TextSize_Period);
   ObjectSetString(0, periodLabelName, OBJPROP_TEXT, "Period: Loading...");
   ObjectSetInteger(0, periodLabelName, OBJPROP_SELECTABLE, false);

//--- NEW: Create Instrument Label
   ObjectCreate(0, instrumentLabelName, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, instrumentLabelName, OBJPROP_XDISTANCE, XOffset_Instrument);
   ObjectSetInteger(0, instrumentLabelName, OBJPROP_YDISTANCE, yPos_Instrument); // Use calculated Y
   ObjectSetInteger(0, instrumentLabelName, OBJPROP_COLOR, TextColor_Instrument);
   ObjectSetInteger(0, instrumentLabelName, OBJPROP_FONTSIZE, TextSize_Instrument);
   ObjectSetString(0, instrumentLabelName, OBJPROP_TEXT, "Instrument: Loading...");
   ObjectSetInteger(0, instrumentLabelName, OBJPROP_SELECTABLE, false);

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
   ObjectDelete(0, periodLabelName);     // NEW: Delete Time Period label
   ObjectDelete(0, instrumentLabelName); // NEW: Delete Instrument label

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
      case 0:
         dayString = "Sunday";
         break;
      case 1:
         dayString = "Monday";
         break;
      case 2:
         dayString = "Tuesday";
         break;
      case 3:
         dayString = "Wednesday";
         break;
      case 4:
         dayString = "Thursday";
         break;
      case 5:
         dayString = "Friday";
         break;
      case 6:
         dayString = "Saturday";
         break;
      default:
         dayString = "Unknown";
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

   if(secondsLeft > periodSeconds || secondsLeft < 0)
      secondsLeft = 0;

   long minutesLeft = secondsLeft / 60;
   long secsRemain = secondsLeft % 60;

   string timeLeftStr = StringFormat("Candle Time Left: %02d:%02d", minutesLeft, secsRemain);
   ObjectSetString(0, timeLeftLabelName, OBJPROP_TEXT, timeLeftStr);

//--- NEW: Display Current Time Period
   string periodString = "";
   switch(Period())
     {
      case PERIOD_M1:
         periodString = "M1";
         break;
      case PERIOD_M5:
         periodString = "M5";
         break;
      case PERIOD_M15:
         periodString = "M15";
         break;
      case PERIOD_M30:
         periodString = "M30";
         break;
      case PERIOD_H1:
         periodString = "H1";
         break;
      case PERIOD_H4:
         periodString = "H4";
         break;
      case PERIOD_D1:
         periodString = "D1";
         break;
      case PERIOD_W1:
         periodString = "W1";
         break;
      case PERIOD_MN1:
         periodString = "MN1";
         break;
      default:
         periodString = "Unknown";
     }
   ObjectSetString(0, periodLabelName, OBJPROP_TEXT, "Period: " + periodString);

//--- NEW: Display Current Instrument
   ObjectSetString(0, instrumentLabelName, OBJPROP_TEXT, "Instrument: " + Symbol());
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
   double  spreadValue;
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
