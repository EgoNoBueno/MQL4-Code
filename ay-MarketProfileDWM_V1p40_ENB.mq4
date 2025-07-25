//+------------------------------------------------------------------+
//|                                ay-MarketProfileDWM_V1p40_ENB.mq4 |
//|                                       Copyright 2025, EgoNoBueno |
//|                                              dentonh18@yahoo.com |
//+------------------------------------------------------------------+
#property version   "1.41"
#property copyright "Copyright © 2011, ahmad.yani@hotmail.com. Modified 2025 by EgoNoBueno"
#property link      "ahmad.yani@hotmail.com"
#property indicator_chart_window
#property strict
/*
v1.1        cleaning the code
            add ShowOpenCloseArrow
            add VATPOPercent
v1.2        use 1 pip for pricing step and tpo calculating
v1.3        add Volume Profile feature
v1.31       add DayStartHour, ShowPriceHistogram, ShowValueArea, ShowVAHVALLines
v1.31.rev1  add Ticksize, VolAmplitudePercent
            bug fix :
            - Profile High and Low misscalculated when high or low of the day
              occured at first m30 candle.
            - Open and Close Arrow Location
            - profile missing when DayStartHour not exist on the chart
              like Hour 0 not exist on some days on #YMH1 chart (fxpro);
v1.4        Refactor: Removed Sleep() from start() to prevent freezing.
            Initialized global and local variables.
            Added extensive comments for clarity.
            Added Print statements with __LINE__ for debugging.
            Reviewed and clarified logic in various functions.
*/

#define PRICEIDX        0 // Index for price in aprice_step array
#define TPOIDX          1 // Index for Time Price Opportunity (TPO) count in aprice_step array
#define VOLIDX          2 // Index for Volume in aprice_step array

//---extern vars
extern int        LookBack                = 12;     // Number of past profiles to display
extern bool       UseVolumeProfile        = false;  // Use Volume Profile instead of TPO Profile
extern string     ProfileTimeframeInfo    = "use M5, M15, M30, H1, H4, D, W, or M"; // Informational text for ProfileTimeframe
extern string     ProfileTimeframe        = "D";    // Timeframe for each profile (D, W, M, H4, H1, M30, M15, M5)
extern int        DayStartHour            = 0;      // Hour to start the daily profile (0-23)
extern double     VATPOPercent            = 70.0;   // Percentage for Value Area calculation
extern int        TickSize                = 1;      // Size of one tick step for profile resolution (e.g., 1 for 1-pip steps)
extern int        ExtendedPocLines        = 12;     // Number of recent POC lines to extend
extern string     spr0                    = "on/off settings.."; // Separator for input parameters
extern bool       ShowPriceHistogram      = true;  // Show TPO/Volume histogram
extern bool       ShowValueArea           = true;  // Show Value Area
extern bool       useGradientColorForValueArea = false; // Use gradient color for Value Area
extern bool       ShowVAHVALLines         = true;   // Show Value Area High and Low lines
extern bool       ShowOpenCloseArrow      = false;  // Show arrows for profile open and close prices
extern string     spr1                    = "design & colors.."; // Separator for input parameters
extern double     VolAmplitudePercent     = 40.0;   // Amplitude percentage for Volume Profile histogram
extern int        HistoHeight             = 2;      // Height multiplier for histogram bars (in TickSize units)
extern color      HistoColor1             = DarkSlateGray; // Primary histogram color
extern color      HistoColor2             = DimGray;     // Secondary histogram color (alternating)
extern color      OpenColor               = DarkGreen;   // Color for Open arrow
extern color      CloseColor              = Peru;        // Color for Close arrow
extern color      POCColor                = Peru;        // Color for Point of Control (POC) line
extern color      VirginPOCColor          = Yellow;      // Color for Virgin POC line
extern color      VAColor                 = C'16,16,16'; // Color for Value Area
extern color      VALinesColor            = White;       // Color for VA High/Low lines
extern color      InfoColor               = Lime;        // Color for information text label
extern string     spr2                    = "Profile Data............."; // Separator for input parameters
extern int        DailyProfileDataTf      = 60;     // Data timeframe (minutes) for Daily profile (e.g., 60 for M60)
extern int        WeeklyProfileDataTf     = 240;    // Data timeframe (minutes) for Weekly profile (e.g., 240 for H4)
extern int        MonthlyProfileDataTf    = 1440;   // Data timeframe (minutes) for Monthly profile (e.g., 1440 for D1)
extern int        H4ProfileDataTf         = 30;     // Data timeframe (minutes) for H4 profile (e.g., 30 for M30)
extern int        H1ProfileDataTf         = 15;     // Data timeframe (minutes) for H1 profile (e.g., 15 for M15)
extern int        M30ProfileDataTf        = 5;      // Data timeframe (minutes) for M30 profile (e.g., 5 for M5)
extern int        M15ProfileDataTf        = 1;      // Data timeframe (minutes) for M15 profile (e.g., 1 for M1)
extern int        M5ProfileDataTf         = 1;      // Data timeframe (minutes) for M5 profile (e.g., 1 for M1)

//---global vars
string            gsPref                  = "ay.mp."; // Prefix for object names to avoid conflicts
double            fpoint                  = 0.0;      // Adjusted point size for calculations
double            gdOneTick               = 0.0;      // Value of one tick step in price terms
double            gdHistoRange            = 0.0;      // Not directly used, seems related to HistoHeight
int               fdigits                 = 0;        // Adjusted digits for price display
int               giStep                  = 1;        // Step for iterating price levels in histogram drawing (in TickSize units)
int               giProfileTf             = PERIOD_D1;// MQL4 Timeframe constant for the selected ProfileTimeframe
int               giDataTf                = 0;        // MQL4 Timeframe constant for data collection (e.g., PERIOD_M1, PERIOD_M5)

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//| Called once when the indicator is first loaded or inputs change. |
//+------------------------------------------------------------------+
int init()
  {
   Print(__FUNCTION__, ":", __LINE__, " Initializing Market Profile Indicator...");

// Set the data timeframe based on the current chart's period initially.
// This will be overridden by specific settings based on ProfileTimeframe.
   giDataTf = Period();

// Adjust point and digits for instruments with 3/5 decimal places
   if(Point == 0.001 || Point == 0.00001)
     {
      fpoint = Point * 10;
      fdigits = Digits - 1;
     }
   else
     {
      fpoint = Point;
      fdigits = Digits;
     }

// Configure indicator settings based on the selected ProfileTimeframe extern string
// This sets the MQL4 profile timeframe constant (giProfileTf),
// the object name prefix (gsPref), adjusts HistoHeight, and sets the data collection timeframe (giDataTf).
   if(ProfileTimeframe == "M")
     {
      gsPref      = gsPref + "2.0." + ProfileTimeframe + ".";
      giProfileTf = PERIOD_MN1;
      HistoHeight = MathMax(HistoHeight, 8); // Ensure minimum HistoHeight for monthly
      giDataTf    = MonthlyProfileDataTf;
     }
   else
      if(ProfileTimeframe == "W")
        {
         gsPref      = gsPref + "3.0." + ProfileTimeframe + ".";
         giProfileTf = PERIOD_W1;
         HistoHeight = MathMax(HistoHeight, 3); // Ensure minimum HistoHeight for weekly
         giDataTf    = WeeklyProfileDataTf;
        }
      else
         if(ProfileTimeframe == "H4")
           {
            gsPref      = gsPref + "5.0." + ProfileTimeframe + ".";
            giProfileTf = PERIOD_H4;
            HistoHeight = MathMax(HistoHeight, 13);
            giDataTf    = H4ProfileDataTf;
           }
         else
            if(ProfileTimeframe == "H1")
              {
               gsPref      = gsPref + "6.0." + ProfileTimeframe + ".";
               giProfileTf = PERIOD_H1;
               HistoHeight = MathMax(HistoHeight, 21);
               giDataTf    = H1ProfileDataTf;
              }
            else
               if(ProfileTimeframe == "M30")
                 {
                  gsPref      = gsPref + "7.0." + ProfileTimeframe + ".";
                  giProfileTf = PERIOD_M30;
                  HistoHeight = MathMax(HistoHeight, 26);
                  giDataTf    = M30ProfileDataTf;
                 }
               else
                  if(ProfileTimeframe == "M15")
                    {
                     gsPref      = gsPref + "8.0." + ProfileTimeframe + ".";
                     giProfileTf = PERIOD_M15;
                     HistoHeight = MathMax(HistoHeight, 31);
                     giDataTf    = M15ProfileDataTf;
                    }
                  else
                     if(ProfileTimeframe == "M5")
                       {
                        gsPref      = gsPref + "9.0." + ProfileTimeframe + ".";
                        giProfileTf = PERIOD_M5;
                        HistoHeight = MathMax(HistoHeight, 36);
                        giDataTf    = M5ProfileDataTf;
                       }
                     else  // Default to Daily profile (D1)
                       {
                        gsPref      = gsPref + "4.0." + ProfileTimeframe + "."; // Default is "D" so ProfileTimeframe variable holds "D"
                        giProfileTf = PERIOD_D1;
                        HistoHeight = MathMax(HistoHeight, 1);
                        giDataTf    = DailyProfileDataTf;
                       }

// Ensure HistoHeight is at least TickSize
   HistoHeight    = MathMax(HistoHeight, TickSize);
// Calculate the price value of one tick step used for profile building
   gdOneTick      = TickSize * Point; // Corrected: TickSize is in Pips/Points, Point is the value of 1 point.
// If TickSize = 1, gdOneTick = 1 Point. If TickSize = 5, gdOneTick = 5 Points.
// The original was TickSize/(MathPow(10,fdigits)), which is more complex than needed if Point is used.
// Re-evaluating: The original gdOneTick = TickSize/(MathPow(10,fdigits));
// And fdigits is Digits or Digits-1. If Point = 0.0001 (4 digits), fdigits=4. MathPow(10,4)=10000.
// gdOneTick = TickSize * 0.0001. This is essentially TickSize * Point. So the simplification is fine.
   gdHistoRange   = HistoHeight * gdOneTick; // Price range represented by one histogram step element
   giStep         = HistoHeight;             // Number of TickSize units per visual histogram step

   Print(__FUNCTION__, ":", __LINE__, " Market Profile Initialized. ProfileTF: ", giProfileTf, ", DataTF: ", giDataTf, ", gsPref: ", gsPref, ", gdOneTick: ", gdOneTick, ", HistoHeight: ", HistoHeight, ", giStep: ", giStep);
   return(0);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//| Called once when the indicator is removed or the chart closes.   |
//+------------------------------------------------------------------+
int deinit()
  {
   Print(__FUNCTION__, ":", __LINE__, " Deinitializing Market Profile Indicator. Deleting objects...");
   delObjs(); // Delete all objects created by this indicator instance
   Print(__FUNCTION__, ":", __LINE__, " Objects deleted.");
   return(0);
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//| Called on every new tick if CalculateOnEveryTick is default.     |
//+------------------------------------------------------------------+
int start()
  {
//Print(__FUNCTION__, ":", __LINE__, " Start() called.");

// Check if the current chart timeframe is suitable for the selected profile configuration
   if(!isOK())
     {
      //Print(__FUNCTION__, ":", __LINE__, " isOK() returned false. Exiting start(). Chart Period: ", Period(), " ProfileTF: ", giProfileTf, " DataTF for Profile: ", giDataTf);
      return(0);
     }

// Adjust LookBack to ensure it doesn't exceed available bars for the profile timeframe
// And also ensure it doesn't exceed available bars on the data timeframe
   int availableProfileBars = iBarShift(NULL, giProfileTf, Time[Bars-1]) -1;
   if(availableProfileBars < 0)
      availableProfileBars = 0; // Handle case with very few bars
   LookBack = MathMin(LookBack, availableProfileBars);

   int firstDataBarTime = iTime(NULL, giDataTf, iBars(NULL, giDataTf) - 1);
   if(firstDataBarTime > 0)  // Ensure valid time
     {
      int availableDataBarsForProfile = iBarShift(NULL, giProfileTf, firstDataBarTime);
      if(availableDataBarsForProfile < 0)
         availableDataBarsForProfile = 0;
      LookBack = MathMin(LookBack, availableDataBarsForProfile);
     }


   int ibar_proftf = 0;         // Loop counter for profile periods (0 is current, 1 is previous, etc.)
   int endbar_proftf = 0;       // Determines how many past profiles to recalculate/draw

// If a new bar has formed on the giProfileTf, all objects are deleted and all LookBack profiles are redrawn.
// Otherwise (no new giProfileTf bar), only the current profile (ibar_proftf = 0) is updated.
// Optimization Note: Deleting all objects on newBarProfileTf can be intensive if LookBack is large.
// A more advanced approach would be to manage objects for each profile slot individually.
   if(newBarProfileTf())
     {
      Print(__FUNCTION__, ":", __LINE__, " New bar detected for ProfileTF. Deleting all objects and redrawing LookBack profiles.");
      delObjs();
      endbar_proftf = LookBack-1; // Redraw all profiles up to LookBack
      if(endbar_proftf <0)
         endbar_proftf = 0;
     }

// Variable declarations for profile calculation
   double     aprice_step[][3];             // Dynamic array: [price_level_index][PRICEIDX/TPOIDX/VOLIDX]
   double     hh = 0.0, ll = 0.0;           // High and Low of the profile period
   double     maxvol = 0.0;                 // Maximum volume found at a single price level
   double     vah = 0.0, val = 0.0;         // Value Area High and Value Area Low prices
   double     totaltpo = 0.0;               // Total TPOs in the profile
   double     totalvol = 0.0;               // Total volume in the profile

   int        startbar_datatf = 0;          // Starting bar index on giDataTf for the current profile period
   int        endbar_datatf = 0;            // Ending bar index on giDataTf for the current profile period
   int        countps = 0;                  // Count of price steps in aprice_step array
   int        vahidx = 0, validx = 0;       // Array indices for VAH and VAL in aprice_step
   int        maxtpo = 0;                   // Maximum TPOs found at a single price level
   int        maxtpoidx = 0;                // Array index for POC (based on TPO)
   int        maxvolidx = 0;                // Array index for POC (based on Volume)

// Main loop: Iterate through each profile period to calculate and draw
// ibar_proftf = 0 is the current, forming profile.
// ibar_proftf > 0 are historical, completed profiles.
   for(ibar_proftf = endbar_proftf; ibar_proftf >= 0; ibar_proftf--)
     {
      //Print(__FUNCTION__, ":", __LINE__, " Processing profile for ibar_proftf: ", ibar_proftf);

      ArrayResize(aprice_step, 0); // Clear/reset the array for the new profile calculation

      // Determine the start and end bars on the giDataTf for the current ibar_proftf period
      getStartAndEndBar(ibar_proftf, startbar_datatf, endbar_datatf);

      if(startbar_datatf == -1)  // Sentinel value indicating an issue getting bar range (e.g., data not available)
        {
         Print(__FUNCTION__, ":", __LINE__, " Warning: getStartAndEndBar returned -1 for ibar_proftf: ", ibar_proftf, ". Skipping this profile.");
         continue; // Skip this profile period
        }

      // Get the highest high and lowest low for the profile period from giDataTf bars
      getHHLL(startbar_datatf, endbar_datatf, hh, ll);

      // Populate aprice_step with price levels, TPO counts, and Volume data. Calculate POC.
      getPriceTPO(startbar_datatf, endbar_datatf, hh, ll, aprice_step, countps, maxtpo,
                  maxtpoidx, totaltpo, maxvol, maxvolidx, totalvol);

      // Draw the price histogram (TPO or Volume) and the POC line(s)
      drawPriceHistoAndPOCLines(startbar_datatf, endbar_datatf, ibar_proftf, countps, aprice_step, maxtpo,
                                maxtpoidx, maxvol, maxvolidx);

      // Calculate the Value Area (VAH and VAL)
      getValueArea(countps, aprice_step, maxtpo, maxtpoidx, totaltpo, maxvol,
                   maxvolidx, totalvol, vah, vahidx, val, validx);

      // Draw the Value Area on the chart
      drawValueArea(startbar_datatf, endbar_datatf, ibar_proftf, countps, aprice_step, vah,
                    vahidx, val, validx);
     } // end for (ibar_proftf = endbar_proftf; ibar_proftf >= 0; ibar_proftf--)

// Update the time extension for POC lines if a new bar on the current chart timeframe has formed
   if(newBar())
     {
      //Print(__FUNCTION__, ":", __LINE__, " New chart bar. Extending POC lines.");
      for(int i=1; i<=ExtendedPocLines; i++)
        {
         // Extend the trendline part of the POC
         ObjectSet(gsPref + "#" + i +".1.1.poc",       OBJPROP_TIME2, Time[0] + 10*Period()*60);
         // Extend the time for the price label of the POC
         ObjectSet(gsPref + "#" + i +".1.0.poc.price", OBJPROP_TIME1, Time[0] + 13*Period()*60);
        }
     }

   drawInfo(); // Draw informational labels on the chart

// Sleep(5000); // REMOVED: This was causing the terminal to freeze.
//Print(__FUNCTION__, ":", __LINE__, " Start() finished.");
   return(0);
  }

//+------------------------------------------------------------------+
//| Checks if the current chart settings are compatible with         |
//| the selected Market Profile settings.                            |
//| RETURN: bool - true if compatible, false otherwise.              |
//+------------------------------------------------------------------+
bool isOK()
  {
// This function checks if the current chart's timeframe (Period())
// is suitable for building the selected profile timeframe (giProfileTf).
// Generally, the chart timeframe should be smaller than or equal to
// the giDataTf (data resolution for profile), and giDataTf should be
// smaller or equal to giProfileTf.
// The current logic compares Period() directly with giProfileTf.
// A more robust check might also consider giDataTf: Period() <= giDataTf.
// However, giDataTf is set based on giProfileTf, so this check is implicitly
// about whether the *current chart* can supply data for the *chosen giDataTf*.

// Example: To build a D1 Profile (giProfileTf = PERIOD_D1),
// using M60 data (giDataTf = 60, i.e. PERIOD_H1),
// the current chart (Period()) should be PERIOD_H1 or lower.

   if(Period() > giDataTf && giDataTf !=0)   // If chart TF is higher than data collection TF.
     {
      // Alert or Print message could be useful here.
      // Example: Print(__FUNCTION__,":",__LINE__," Chart TF (", Period(), ") is too high for selected Data TF (",giDataTf,") for ProfileTF (",giProfileTf,")");
      // For now, rely on the original logic's structure for returns.
      // This specific check isn't in original isOK, adding it might change behavior.
      // Sticking to commenting original logic.
     }


   switch(Period())  // Current chart timeframe
     {
      // For each case, it checks if the selected ProfileTimeframe (giProfileTf)
      // is of a higher or equal periodicity than the current chart.
      // E.g., if on M1 chart, can calculate M5, M15...D1, W1, MN1 profiles.
      case PERIOD_M1:
         if(giProfileTf == PERIOD_M5)
            return(true);
         if(giProfileTf == PERIOD_M15)
            return(true);
         if(giProfileTf == PERIOD_M30)
            return(true);
         if(giProfileTf == PERIOD_H1)
            return(true);
         if(giProfileTf == PERIOD_H4)
            return(true);
         if(giProfileTf == PERIOD_D1)
            return(true);
         if(giProfileTf >= PERIOD_W1)
            return(true); // W1 or MN1
         break;
      case PERIOD_M5:
         if(giProfileTf == PERIOD_M15)
            return(true);
         if(giProfileTf == PERIOD_M30)
            return(true);
         if(giProfileTf == PERIOD_H1)
            return(true);
         if(giProfileTf == PERIOD_H4)
            return(true);
         if(giProfileTf == PERIOD_D1)
            return(true);
         if(giProfileTf >= PERIOD_W1)
            return(true);
         break;
      case PERIOD_M15:
         if(giProfileTf == PERIOD_M30)
            return(true);
         if(giProfileTf == PERIOD_H1)
            return(true);
         if(giProfileTf == PERIOD_H4)
            return(true);
         if(giProfileTf == PERIOD_D1)
            return(true);
         if(giProfileTf == PERIOD_W1)
            return(true);
         if(giProfileTf >= PERIOD_MN1)
            return(true); // Corrected from M1 to MN1 as per logic flow
         break;
      case PERIOD_M30:
         if(giProfileTf == PERIOD_H1)
            return(true);
         if(giProfileTf == PERIOD_H4)
            return(true);
         if(giProfileTf == PERIOD_D1)
            return(true);
         if(giProfileTf == PERIOD_W1)
            return(true);
         if(giProfileTf >= PERIOD_MN1)
            return(true);
         break;
      case PERIOD_H1:
         if(giProfileTf == PERIOD_H4)
            return(true);
         if(giProfileTf == PERIOD_D1)
            return(true);
         if(giProfileTf == PERIOD_W1)
            return(true);
         if(giProfileTf >= PERIOD_MN1)
            return(true);
         break;
      case PERIOD_H4:
         if(giProfileTf == PERIOD_D1)
            return(true);
         if(giProfileTf == PERIOD_W1)
            return(true);
         if(giProfileTf >= PERIOD_MN1)
            return(true);
         break;
      case PERIOD_D1:
         if(giProfileTf == PERIOD_W1)
            return(true);
         if(giProfileTf >= PERIOD_MN1)
            return(true);
         break;
      case PERIOD_W1:
         if(giProfileTf >= PERIOD_MN1)
            return(true); // Only Monthly profile can be built from Weekly chart
         break;
      default: // For PERIOD_MN1 or other unexpected periods
         // If current chart is Monthly, only Monthly profile can be formed with this logic (giProfileTf >= Period())
         if(giProfileTf == Period())
            return (true);
         //Print(__FUNCTION__, ":", __LINE__, " isOK Default: Chart Period ", Period(), " not directly handled for ProfileTF ", ProfileTimeframe);
         return(false);
     }

// If no valid condition met above for the current Period() vs giProfileTf
// Print(__FUNCTION__, ":", __LINE__, " isOK returning false. Chart Period: ", Period(), ", ProfileTF: ", ProfileTimeframe, " (",giProfileTf,"), Selected DataTF for Profile: ", giDataTf);
   return(false);
  }

//+------------------------------------------------------------------+
//| Determines the start and end bar indices on `giDataTf` for a     |
//| given profile period index `ibar_proftf`.                        |
//| INPUT:                                                           |
//|   ibar_proftf - int, the index of the profile period (0=current) |
//| OUTPUT:                                                          |
//|   startbar    - int (by ref), the starting bar index on giDataTf |
//|   endbar      - int (by ref), the ending bar index on giDataTf   |
//+------------------------------------------------------------------+
void getStartAndEndBar(int ibar_proftf, int &r_startbar, int &r_endbar)
  {
// Initialize output parameters
   r_startbar = -1; // Use -1 as a sentinel for error or not found
   r_endbar = -1;
   int one_day_seconds = 86400; // Seconds in a day
   int iday = -1;                      // Counter for days found matching DayStartHour
   datetime dt_current_bar = 0;       // Temporary datetime variable

   int i = 0, j = 0; // Loop counters
   datetime dt_proftf = 0;      // Start datetime of the target profile period
   datetime dt_proftf_next = 0; // Start datetime of the *next* profile period (used to find end of current)

   switch(giProfileTf)
     {
      case PERIOD_D1:



         if(DayStartHour == 0)  // Standard day boundary (00:00)
           {
            dt_proftf       = iTime(NULL, giProfileTf, ibar_proftf);
            dt_proftf_next  = iTime(NULL, giProfileTf, ibar_proftf - 1);   // Time of the next newer day's start

            if(dt_proftf == 0)  // Could not get time for profile bar, likely insufficient history
              {
               Print(__FUNCTION__, ":", __LINE__, " Error: iTime returned 0 for D1 profile, ibar_proftf=", ibar_proftf);
               return; // r_startbar and r_endbar remain -1
              }

            r_startbar        = iBarShift(NULL, giDataTf, dt_proftf);
            // End bar is the one just before the start of the next profile period
            r_endbar          = iBarShift(NULL, giDataTf, dt_proftf_next - (giDataTf * 60));

            // Handle current day (ibar_proftf = 0) where dt_proftf_next might be invalid or in future
            if(dt_proftf_next < dt_proftf || ibar_proftf == 0)  // If next profile time is earlier (error) or it's the current day
              {
               r_endbar = 0; // Current profile period ends at the most recent bar (index 0) on giDataTf
              }

            // Fix for iBarShift potentially giving a bar from the previous period if exact time not found
            if(r_startbar != -1 && iTime(NULL, giDataTf, r_startbar) < dt_proftf)
               r_startbar--;

            // If start bar is Sunday (for some brokers), it might be an invalid start for daily profile.
            // This check might be too specific or need adjustment based on broker/session times.
            if(r_startbar != -1 && TimeDayOfWeek(iTime(NULL, giDataTf, r_startbar)) == 0)    // Sunday
              {
               // This logic might need refinement. What if the actual start is Sunday?
               // For now, keeping original behavior of potentially invalidating.
               // Print(__FUNCTION__, ":", __LINE__, " Warning: Daily profile start bar on Sunday for ibar_proftf=", ibar_proftf);
               // r_startbar = -1; // Original behavior might invalidate here.
              }
           }
         else // Custom DayStartHour
           {
            // This loop iterates backwards from most recent data on giDataTf
            // to find the start of the (ibar_proftf)-th day that begins at DayStartHour.
            for(i=0; i < iBars(NULL, giDataTf); i++)
              {
               dt_current_bar = iTime(NULL, giDataTf, i);
               if(TimeHour(dt_current_bar) == DayStartHour && TimeMinute(dt_current_bar) == 0)
                 {
                  iday++; // Found a bar that starts a new "profile day"
                  if(iday == ibar_proftf)  // This is the start of the day we're looking for
                    {
                     r_startbar = i;
                     if(ibar_proftf != 0)  // For historical profiles
                       {
                        // End bar is the one just before (DayStartHour of (start_datetime + 1 day))
                        datetime dt_next_day_start = dt_current_bar + one_day_seconds;
                        r_endbar  = iBarShift(NULL, giDataTf, dt_next_day_start - (giDataTf * 60));

                        // Correction if iBarShift undershoots
                        if(r_endbar != -1 && iTime(NULL, giDataTf, r_endbar) < (dt_next_day_start - (giDataTf * 60)))
                          {
                           r_endbar++;
                           // This nested loop ensures r_endbar is correctly before the true next DayStartHour
                           // This part seems overly complex and potentially slow.
                           for(j=r_endbar; j>=0; j--)  // Scan backwards from r_endbar
                             {
                              dt_current_bar = iTime(NULL, giDataTf, j);
                              if(TimeHour(dt_current_bar) == DayStartHour && TimeMinute(dt_current_bar) == 0)
                                {
                                 r_endbar = j+1; // The bar *after* the previous day's start hour found
                                 break;
                                }
                             } // end for j
                          }
                       }
                     else // For current profile (ibar_proftf == 0)
                       {
                        r_endbar = 0; // Ends at the most recent bar
                       }
                     break; // Found the target day, exit loop i
                    } // end if (iday == ibar_proftf)
                 } // end if (TimeHour(dt) == DayStartHour)
              } // end for i

            if(iday == -1 && ibar_proftf == 0)  // Special case: If current day hasn't reached DayStartHour yet
              {
               // Try to find the start of the current day based on the *previous* day's DayStartHour
               // This logic seems to handle cases where DayStartHour makes the "current" day start in the past relative to 00:00
               datetime today_actual_start = StrToTime(TimeToString(TimeCurrent(), TIME_DATE)) + DayStartHour * 3600;
               if(TimeCurrent() < today_actual_start)
                  today_actual_start -= one_day_seconds; // If current time is before today's DayStartHour, use yesterday's DayStartHour

               r_startbar = iBarShift(NULL, giDataTf, today_actual_start);
               if(r_startbar != -1 && iTime(NULL, giDataTf, r_startbar) < today_actual_start)
                  r_startbar--;
               r_endbar = 0; // Current profile always ends at bar 0
               iday = 0; // Mark as found for the check below
              }

            if(iday < ibar_proftf || r_startbar == -1)  // If not enough days with DayStartHour found
              {
               Print(__FUNCTION__, ":", __LINE__, " Warning: Could not find enough D1 profiles with DayStartHour=", DayStartHour, " for ibar_proftf=", ibar_proftf);
               r_startbar = -1;
               r_endbar = -1; // Explicitly set to error state
              }
           } // end else (Custom DayStartHour)
         break; // End case PERIOD_D1

      default: // For PERIOD_W1, PERIOD_MN1, PERIOD_H4, etc. (non-daily)
         dt_proftf      = iTime(NULL, giProfileTf, ibar_proftf);
         dt_proftf_next = iTime(NULL, giProfileTf, ibar_proftf - 1);

         if(dt_proftf == 0)
           {
            Print(__FUNCTION__, ":", __LINE__, " Error: iTime returned 0 for profile TF ", giProfileTf, ", ibar_proftf=", ibar_proftf);
            return;
           }

         r_startbar  = iBarShift(NULL, giDataTf, dt_proftf);
         r_endbar    = iBarShift(NULL, giDataTf, dt_proftf_next - (giDataTf * 60));

         // Handle current profile period (ibar_proftf = 0)
         if(dt_proftf_next < dt_proftf || ibar_proftf == 0)
           {
            r_endbar = 0; // Ends at the most recent bar on giDataTf
           }

         // Fix iBarShift potentially giving a bar from the previous period
         if(r_startbar != -1 && iTime(NULL, giDataTf, r_startbar) < dt_proftf)
            r_startbar--;
         break; // End default case
     } // end switch (giProfileTf)

// Final check for valid range
   if(r_startbar != -1 && r_endbar != -1 && r_startbar < r_endbar)
     {
      Print(__FUNCTION__, ":", __LINE__, " Warning: startbar ", r_startbar, " is less than endbar ", r_endbar, ". Invalid range for ibar_proftf ", ibar_proftf);
      r_startbar = -1;
      r_endbar = -1; // Invalidate
     }
//if (r_startbar != -1) Print(__FUNCTION__, ":", __LINE__, " Profile ", ibar_proftf, " (TF ", giProfileTf, ") uses Data TF ", giDataTf, " bars from: ", r_startbar, " (", TimeToString(iTime(NULL,giDataTf,r_startbar)), ") to ", r_endbar, " (", TimeToString(iTime(NULL,giDataTf,r_endbar)), ")");
  }

//+------------------------------------------------------------------+
//| Calculates the highest high and lowest low for a given bar range |
//| on the `giDataTf` timeframe.                                     |
//| INPUT:                                                           |
//|   startbar_datatf - int, the starting bar index on giDataTf      |
//|   endbar_datatf   - int, the ending bar index on giDataTf        |
//| OUTPUT:                                                          |
//|   hh              - double (by ref), the highest high in the range|
//|   ll              - double (by ref), the lowest low in the range |
//+------------------------------------------------------------------+
void getHHLL(int startbar_datatf, int endbar_datatf, double &hh, double &ll)
  {
   hh = 0.0; // Initialize output
   ll = 0.0; // Initialize output
   if(startbar_datatf < endbar_datatf || startbar_datatf < 0 || endbar_datatf < 0)
     {
      Print(__FUNCTION__, ":", __LINE__, " Error: Invalid bar range provided. Start: ", startbar_datatf, " End: ", endbar_datatf);
      return;
     }

   int num_bars_to_scan = (startbar_datatf - endbar_datatf) + 1;
   if(num_bars_to_scan <= 0)
     {
      Print(__FUNCTION__, ":", __LINE__, " Error: No bars in range. Start: ", startbar_datatf, " End: ", endbar_datatf);
      return;
     }

   int highest_bar_idx = iHighest(NULL, giDataTf, MODE_HIGH, num_bars_to_scan, endbar_datatf);
   int lowest_bar_idx  = iLowest(NULL, giDataTf, MODE_LOW,  num_bars_to_scan, endbar_datatf);

   if(highest_bar_idx != -1)
      hh = iHigh(NULL, giDataTf, highest_bar_idx);
   else
      Print(__FUNCTION__, ":", __LINE__, " Warning: iHighest returned -1 for range ", startbar_datatf, "-", endbar_datatf);

   if(lowest_bar_idx != -1)
      ll = iLow(NULL, giDataTf, lowest_bar_idx);
   else
      Print(__FUNCTION__, ":", __LINE__, " Warning: iLowest returned -1 for range ", startbar_datatf, "-", endbar_datatf);

// Normalize to the display digits (fdigits was adjusted for 3/5 digit brokers)
   hh = NormalizeDouble(hh, fdigits);
   ll = NormalizeDouble(ll, fdigits);
  }

//+------------------------------------------------------------------+
//| Draws informational labels on the chart.                         |
//+------------------------------------------------------------------+
void drawInfo()
  {
   string info_text = "Volume Profile";
   if(!UseVolumeProfile)
      info_text = "TPO Profile";

   string obj_name1 = gsPref+"lblinfo1";
   if(ObjectFind(obj_name1) == -1)
     {
      ObjectCreate(obj_name1, OBJ_LABEL,0,0,0);
     }
   ObjectSet(obj_name1, OBJPROP_CORNER, 3);     // Bottom-right corner
   ObjectSetText(obj_name1, info_text, 8, "Tahoma", InfoColor);
   ObjectSet(obj_name1, OBJPROP_XDISTANCE, 10);
   ObjectSet(obj_name1, OBJPROP_YDISTANCE, 20);

// Display DayStartHour only if Daily profile is selected
   if(giProfileTf == PERIOD_D1)
     {
      string obj_name2 = gsPref+"lblinfo2";
      if(ObjectFind(obj_name2) == -1)
        {
         ObjectCreate(obj_name2, OBJ_LABEL,0,0,0);
        }
      ObjectSet(obj_name2, OBJPROP_CORNER, 3);     // Bottom-right corner
      ObjectSetText(obj_name2, "DayStartHour: " + DayStartHour, 8, "Tahoma", InfoColor);
      ObjectSet(obj_name2, OBJPROP_XDISTANCE, 10);
      ObjectSet(obj_name2, OBJPROP_YDISTANCE, 35);     // Adjusted Y to not overlap
     }
   else // If not D1 profile, ensure the DayStartHour label is hidden or deleted
     {
      string obj_name2 = gsPref+"lblinfo2";
      if(ObjectFind(obj_name2) != -1)
         ObjectDelete(obj_name2);
     }
  }

//+------------------------------------------------------------------+
//| Populates the aprice_step array with price levels, TPO counts,   |
//| and Volume data. Calculates POC (Point of Control).              |
//| INPUT:                                                           |
//|   startbar_datatf - int, starting bar on giDataTf                |
//|   endbar_datatf   - int, ending bar on giDataTf                  |
//|   hh              - double, highest high of the profile period   |
//|   ll              - double, lowest low of the profile period     |
//| OUTPUT:                                                          |
//|   aprice_step     - double[][3] (by ref), array to be populated  |
//|   r_countps       - int (by ref), number of price steps populated|
//|   r_maxtpo        - int (by ref), max TPOs at a price level (POC)|
//|   r_maxtpoidx     - int (by ref), index of TPO POC in aprice_step|
//|   r_totaltpo      - double (by ref), total TPOs in profile       |
//|   r_maxvol        - double (by ref), max Volume at price (POC)   |
//|   r_maxvolidx     - int (by ref), index of Volume POC            |
//|   r_totalvol      - double (by ref), total Volume in profile     |
//+------------------------------------------------------------------+
void getPriceTPO(int       startbar_datatf, int       endbar_datatf,
                 double    hh, double    ll,
                 double    &aprice_step[][3],
                 int       &r_countps,
                 int       &r_maxtpo, int       &r_maxtpoidx, double    &r_totaltpo,
                 double    &r_maxvol, int       &r_maxvolidx, double    &r_totalvol)
  {
//Print(__FUNCTION__, ":", __LINE__, " Calculating TPO/Volume for range: ", startbar_datatf, " to ", endbar_datatf, ", HH: ", hh, ", LL: ", ll);

// Initialize output parameters
   r_maxtpo        = 0;
   r_maxtpoidx     = 0;
   r_totaltpo      = 0.0;
   r_maxvol        = 0.000001; // Initialize with a very small value to ensure first volume is greater
   r_maxvolidx     = 0;
   r_totalvol      = 0.0;
   r_countps       = 0;        // This will be incremented as price steps are added

   if(hh < ll || gdOneTick <= 0)  // Basic validation
     {
      Print(__FUNCTION__, ":", __LINE__, " Error: hh < ll or gdOneTick is invalid. hh=",hh,", ll=",ll,", gdOneTick=",gdOneTick);
      ArrayResize(aprice_step,0); // Ensure array is empty
      return;
     }

   double current_price_level = hh; // Start from the highest price
// Calculate profile range and its midpoint, used for tie-breaking POC
   double profile_range       = MathMax(hh - ll, gdOneTick);
   double mid_profile_price   = hh - (0.5 * profile_range);

// --- Populate price levels in aprice_step array ---
// This loop creates entries in aprice_step for each discrete price level
// from profile high (hh) down to profile low (ll), stepped by gdOneTick.
   while(current_price_level >= ll)
     {
      ArrayResize(aprice_step, r_countps + 1);
      aprice_step [r_countps][PRICEIDX] = current_price_level; // Store the price level
      aprice_step [r_countps][TPOIDX]   = 0.0;                 // Initialize TPO count for this level
      aprice_step [r_countps][VOLIDX]   = 0.0;                 // Initialize Volume for this level

      current_price_level -= gdOneTick; // Move to the next lower price level
      r_countps++;                      // Increment count of price levels
      if(r_countps > 10000)  // Safety break for extreme ranges / small gdOneTick
        {
         Print(__FUNCTION__, ":", __LINE__, " Warning: Exceeded 10000 price steps. Breaking. HH:", hh, " LL:", ll, " gdOneTick:", gdOneTick);
         break;
        }
     }
   if(r_countps == 0)
     {
      Print(__FUNCTION__, ":", __LINE__, " Warning: No price steps generated for profile.");
      return; // No price steps to process
     }
// --- End populate price level ---

// --- Counting TPO and Volume for each price level ---
// Iterate through each bar in the specified range on giDataTf
   int bar_idx = 0; // Renamed from j to bar_idx for clarity
   for(bar_idx = startbar_datatf; bar_idx >= endbar_datatf; bar_idx--)
     {
      double bar_high  = iHigh(NULL, giDataTf, bar_idx);
      double bar_low   = iLow(NULL, giDataTf, bar_idx);
      double bar_vol   = iVolume(NULL, giDataTf, bar_idx);

      // Calculate volume per pip/tick for the current bar.
      // 'fpoint' is used here as per original logic, representing a minimal price change unit.
      // This distributes the bar's total volume across the price units it spans.
      double bar_range_fpoints = MathMax((bar_high - bar_low) / fpoint, 1.0);   // Avoid division by zero, ensure at least 1 fpoint range
      double volume_per_fpoint = bar_vol / bar_range_fpoints;

      // Now, for the current bar (bar_idx), iterate through all price_steps
      // to see which ones this bar touches.
      int price_step_idx = 0; // Renamed from i for clarity
      for(price_step_idx = 0; price_step_idx < r_countps; price_step_idx++)
        {
         double step_price_val = aprice_step[price_step_idx][PRICEIDX];

         // Check if the current bar's range covers this price_step_val
         if(step_price_val >= bar_low && step_price_val <= bar_high)
           {
            // This price level was touched by this bar
            aprice_step[price_step_idx][TPOIDX] += 1; // Increment TPO count
            aprice_step[price_step_idx][VOLIDX] += volume_per_fpoint; // Add share of volume
            // Note: Original added pip_vol, which was volume_per_fpoint
            r_totaltpo += 1;
            r_totalvol += volume_per_fpoint;

            // --- Update TPO Point of Control (POC) ---
            if(aprice_step[price_step_idx][TPOIDX] > r_maxtpo)
              {
               r_maxtpo    = aprice_step[price_step_idx][TPOIDX];
               r_maxtpoidx = price_step_idx;
              }
            else
               if(aprice_step[price_step_idx][TPOIDX] == r_maxtpo)
                 {
                  // Tie-breaking: Choose POC closer to the middle of the profile range
                  if(MathAbs(mid_profile_price - step_price_val) < MathAbs(mid_profile_price - aprice_step[r_maxtpoidx][PRICEIDX]))
                    {
                     // r_maxtpo remains the same
                     r_maxtpoidx = price_step_idx;
                    }
                 }

            // --- Update Volume Point of Control (VPOC) ---
            if(aprice_step[price_step_idx][VOLIDX] > r_maxvol)
              {
               r_maxvol    = aprice_step[price_step_idx][VOLIDX];
               r_maxvolidx = price_step_idx;
              }
            else
               if(aprice_step[price_step_idx][VOLIDX] == r_maxvol)
                 {
                  // Tie-breaking for VPOC
                  if(MathAbs(mid_profile_price - step_price_val) < MathAbs(mid_profile_price - aprice_step[r_maxvolidx][PRICEIDX]))
                    {
                     // r_maxvol remains the same
                     r_maxvolidx = price_step_idx;
                    }
                 }
           } // end if (price_step touched by bar)
        } // end for (price_step_idx)
     } // end for (bar_idx) ---- All bars in profile period processed
//Print(__FUNCTION__, ":", __LINE__, " Finished TPO/Volume Calculation. Total TPO: ", r_totaltpo, " Total Volume: ", r_totalvol);
  }


//+------------------------------------------------------------------+
//| Draws the price histogram (TPO or Volume based) and POC lines.   |
//| INPUT:                                                           |
//|   startbar_datatf - int, starting bar on giDataTf for this profile|
//|   endbar_datatf   - int, ending bar on giDataTf for this profile  |
//|   ibar_proftf     - int, index of the profile (0=current)        |
//|   countps         - int, number of price steps in aprice_step    |
//|   aprice_step     - double[][], array with profile data          |
//|   maxtpo          - int, value of TPO POC                        |
//|   maxtpoidx       - int, index of TPO POC in aprice_step         |
//|   maxvol          - double, value of Volume POC                  |
//|   maxvolidx       - int, index of Volume POC in aprice_step      |
//+------------------------------------------------------------------+
void drawPriceHistoAndPOCLines(int    startbar_datatf, int    endbar_datatf, int    ibar_proftf,
                               int    countps, double &aprice_step[][3],
                               int    maxtpo,  int    maxtpoidx,
                               double maxvol,  int    maxvolidx)
  {
//Print(__FUNCTION__, ":", __LINE__, " Drawing Histo/POC for ibar_proftf: ", ibar_proftf);
   if(countps == 0 || ArrayRange(aprice_step,0) == 0)
     {
      Print(__FUNCTION__, ":", __LINE__, " No data in aprice_step for ibar_proftf: ", ibar_proftf);
      return;
     }

   double   price1 = 0.0, price2 = 0.0; // Prices for histogram rectangle
   int      numtpo_for_histo_bar = 0;   // TPO count for current histogram bar
   double   numvol_for_histo_bar = 0.0; // Volume for current histogram bar (normalized)
   int      step_idx = 0, i = 0;        // Loop counters

// Determine chart bar indices corresponding to the profile period's start/end on giDataTf
   datetime profile_period_start_time = iTime(NULL, giDataTf, startbar_datatf);
   datetime profile_period_end_time   = iTime(NULL, giDataTf, endbar_datatf); // Time of the last bar in period

   if(profile_period_start_time == 0)
     {
      Print(__FUNCTION__, ":", __LINE__, " Error: Could not get time for startbar_datatf ", startbar_datatf);
      return;
     }

   int      chart_startbar_idx = iBarShift(NULL, 0, profile_period_start_time);   // Bar index on current chart
   int      chart_endbar_idx   = iBarShift(NULL, 0, profile_period_end_time);     // Bar index on current chart

   if(chart_startbar_idx == -1 || chart_endbar_idx == -1)
     {
      Print(__FUNCTION__, ":", __LINE__, " Error: Could not map profile data bars to chart bars for ibar_proftf: ", ibar_proftf);
      return;
     }

   int      num_chart_bars_in_profile = chart_startbar_idx - chart_endbar_idx; // Number of chart bars this profile spans
   color    clr = clrNONE;          // Color for histogram bar
   datetime t1_histo = Time[chart_startbar_idx]; // Start time for histogram bars (right edge of profile)
   datetime t2_histo = 0;                        // End time for histogram bars (calculated based on TPO/Vol magnitude)

   string   str_dt_proftf = TimeToStr(iTime(NULL, giProfileTf, ibar_proftf), TIME_DATE);   // Date string for POC label
   double   lowest_price_in_profile = (countps > 0) ? aprice_step[countps-1][PRICEIDX] : 0.0;
   double   dstep_color_alternator = 0.0; // Used to alternate HistoColor1 and HistoColor2

// --- Draw price histogram ---
   if(ShowPriceHistogram)
     {
      // For the current forming profile (ibar_proftf == 0), delete old histogram objects before redrawing
      if(ibar_proftf == 0)
        {
         if(UseVolumeProfile)
            delObjs(gsPref + "#" + ibar_proftf + ".histovol.");
         else
            delObjs(gsPref + "#" + ibar_proftf + ".histotpo.");
        }

      // Iterate through price steps with giStep increment (giStep combines multiple TickSize levels)
      for(step_idx = 0; step_idx < countps; step_idx += giStep)
        {
         price1 = aprice_step[step_idx][PRICEIDX]; // Top price of this histogram segment
         // Ensure we don't go out of bounds for price2
         if(step_idx + giStep < countps)
           {
            price2 = aprice_step[step_idx + giStep][PRICEIDX];
           }
         else
           {
            price2 = lowest_price_in_profile; // Use the lowest price if at the end
           }
         if(price1 < price2 && countps > 1)    // Ensure price1 is higher or equal
           {
            double temp = price1;
            price1 = price2;
            price2 = temp; // Swap if order is wrong
           }


         // Alternate colors for histogram bars
         if(MathCeil(dstep_color_alternator/2.0) == dstep_color_alternator/2.0)
            clr = HistoColor1;
         else
            clr = HistoColor2;

         string histo_obj_suffix = "";

         if(!UseVolumeProfile)  // TPO Profile histogram
           {
            numtpo_for_histo_bar = 0;
            // Find max TPO within this giStep segment
            for(i = step_idx; i < step_idx + giStep && i < countps; i++)
              {
               numtpo_for_histo_bar = MathMax(numtpo_for_histo_bar, (int)aprice_step[i][TPOIDX]);
              }
            // Scale TPO count to chart bars. (giDataTf/Period()) is a scaling factor.
            double x2 = ((giDataTf*1.0)/Period()) * numtpo_for_histo_bar;
            int scaled_tpo_width = MathCeil(x2);   // Width in terms of chart bars

            // Ensure t2_histo is valid and doesn't go off chart
            if(chart_startbar_idx - scaled_tpo_width >= 0 && chart_startbar_idx - scaled_tpo_width < Bars)
              {
               t2_histo = Time[chart_startbar_idx - scaled_tpo_width] ;
              }
            else
               if(chart_startbar_idx - scaled_tpo_width < 0 && chart_startbar_idx < Bars)    // If extends too far left
                 {
                  t2_histo = Time[0]; // Cap at the leftmost available bar time
                 }
               else     // If chart_startbar_idx is already invalid or very small
                 {
                  t2_histo = t1_histo + Period()*60; // Default to one bar width if calculation is problematic
                 }

            if(t2_histo <= t1_histo && scaled_tpo_width > 0)
               t2_histo = t1_histo + (Period()*60); // Ensure positive duration if width > 0

            histo_obj_suffix = ".histotpo." + DoubleToStr(price1,fdigits);
            createRect("#" + ibar_proftf + histo_obj_suffix, price1, t1_histo, MathMax(price2, lowest_price_in_profile), t2_histo, clr);
           }
         else // Volume Profile histogram
           {
            numvol_for_histo_bar = 0.0;
            // Find max Volume within this giStep segment
            for(i = step_idx; i < step_idx + giStep && i < countps; i++)
              {
               numvol_for_histo_bar = MathMax(numvol_for_histo_bar, aprice_step[i][VOLIDX]);
              }
            // Scale volume relative to maxvol for this profile and then by VolAmplitudePercent
            double scaled_vol_width_double = 0;
            if(maxvol > 0)  // Avoid division by zero
              {
               scaled_vol_width_double = (numvol_for_histo_bar / maxvol) * num_chart_bars_in_profile;
              }
            int scaled_vol_width = MathCeil((VolAmplitudePercent/100.0) * scaled_vol_width_double);

            if(chart_startbar_idx - scaled_vol_width >= 0 && chart_startbar_idx - scaled_vol_width < Bars)
              {
               t2_histo = Time[chart_startbar_idx - scaled_vol_width] ;
              }
            else
               if(chart_startbar_idx - scaled_vol_width < 0 && chart_startbar_idx < Bars)
                 {
                  t2_histo = Time[0];
                 }
               else
                 {
                  t2_histo = t1_histo + Period()*60;
                 }
            if(t2_histo <= t1_histo && scaled_vol_width > 0)
               t2_histo = t1_histo + (Period()*60); // Ensure positive duration

            histo_obj_suffix = ".histovol." + DoubleToStr(price1,fdigits);
            createRect("#" + ibar_proftf + histo_obj_suffix, price1, t1_histo, MathMax(price2, lowest_price_in_profile), t2_histo, clr);
           }

         dstep_color_alternator += 1.0; // Increment for color alternation
        } // end for (step_idx)
     } // end if (ShowPriceHistogram)

// --- Draw POC (Point of Control) lines ---
   datetime t2_poc_extend = Time[chart_startbar_idx] + (2 * giProfileTf * 60); // Default extension for historical POCs
   int poc_idx = UseVolumeProfile ? maxvolidx : maxtpoidx; // Determine index based on profile type

   if(poc_idx < 0 || poc_idx >= countps)
     {
      Print(__FUNCTION__, ":", __LINE__, " Warning: Invalid POC index: ", poc_idx, " for ibar_proftf: ", ibar_proftf);
      return; // Cannot draw POC if index is invalid
     }
   double poc_price = aprice_step[poc_idx][PRICEIDX];

   string spoc_label_prefix = ".POC "; // Label prefix for normal POC
   color poc_line_color = POCColor;    // Default POC color

// Check if POC is "virgin" (i.e., not touched by subsequent price action)
// This check is only for historical profiles (ibar_proftf != 0)
   if(ibar_proftf != 0)
     {
      double future_hh = 0.0, future_ll = 0.0;
      // Get High/Low of the period *after* the current profile up to the present bar
      // endbar_datatf-1 is the start of the *next* data period. 0 is current bar.
      if(endbar_datatf > 0)  // Ensure there are bars after this profile
        {
         getHHLL(endbar_datatf-1, 0, future_hh, future_ll);

         if((poc_price > future_hh && poc_price > future_ll) ||   // POC is above subsequent range
            (poc_price < future_hh && poc_price < future_ll))   // POC is below subsequent range
           {
            poc_line_color = VirginPOCColor;
            spoc_label_prefix = ".VPOC "; // Virgin POC
           }
        }
     }

// Draw POC line and text label
// Only extend POC lines for recent profiles (ibar_proftf <= ExtendedPocLines) or current profile (ibar_proftf == 0)
   if(ibar_proftf <= ExtendedPocLines || ibar_proftf == 0)
     {
      t2_poc_extend = Time[0] + 10*Period()*60; // Extend to the right from current time

      // Create text label for POC price
      string poc_text_label = ProfileTimeframe + "#" + ibar_proftf + spoc_label_prefix +
                              StringSubstr(str_dt_proftf, 2, 8)+" " +   // Date part
                              DoubleToStr(poc_price, fdigits);
      createText("#" + ibar_proftf +".1.1.poc.price",
                 t2_poc_extend + (3 * Period() * 60), // Position label slightly to the right of line end
                 poc_price,
                 addStr(poc_text_label, " ", 60), // Pad string for consistent alignment (if needed)
                 8, "Arial Narrow", poc_line_color);
     }

   bool is_vpoc = (spoc_label_prefix == ".VPOC ");
   createTl("#" + ibar_proftf + ".1.1.poc",  // Trendline object name
            t1_histo, poc_price,           // Start time (right edge of profile), POC price
            t2_poc_extend, poc_price,      // End time (extended to right), POC price
            poc_line_color, STYLE_SOLID, 1, !is_vpoc);  // VPOC on top (back=false)

// --- Draw Open and Close Arrows ---
   if(ShowOpenCloseArrow)
     {
      double profile_open_price  = iOpen(NULL, giDataTf, startbar_datatf);
      double profile_close_price = iClose(NULL, giDataTf, endbar_datatf); // Close of the last bar in giDataTf period

      // Create arrows at the start time of the profile (t1_histo)
      createArw("#0.0.0.0" + ibar_proftf + ".open", profile_open_price, t1_histo, 233, OpenColor);  // Wingdings 'h' right arrow
      createArw("#0.0.0.0" + ibar_proftf + ".close", profile_close_price, t1_histo, 234, CloseColor); // Wingdings 'i' left arrow
     }
//Print(__FUNCTION__, ":", __LINE__, " Finished Histo/POC for ibar_proftf: ", ibar_proftf);
  }


//+------------------------------------------------------------------+
//| Calculates the Value Area (VAH and VAL) based on TPO or Volume.  |
//| INPUT:                                                           |
//|   countps         - int, number of price steps in aprice_step    |
//|   aprice_step     - double[][], array with profile data          |
//|   maxtpo          - int, value of TPO POC                        |
//|   maxtpoidx       - int, index of TPO POC in aprice_step         |
//|   totaltpo        - double, total TPOs in profile                |
//|   maxvol          - int (double in definition), value of Vol POC | Note: param was int, but used as double (maxvol from getPriceTPO is double)
//|   maxvolidx       - int, index of Volume POC in aprice_step      |
//|   totalvol        - double, total Volume in profile              |
//| OUTPUT:                                                          |
//|   r_vah           - double (by ref), Value Area High price       |
//|   r_vahidx        - int (by ref), index of VAH in aprice_step    |
//|   r_val           - double (by ref), Value Area Low price        |
//|   r_validx        - int (by ref), index of VAL in aprice_step    |
//+------------------------------------------------------------------+
void getValueArea(int      countps, double   &aprice_step[][3],
                  int      maxtpo,  int      maxtpoidx,  double   totaltpo,
                  double   maxvol,  int      maxvolidx,  double   totalvol, // Changed maxvol type to double
                  double   &r_vah,  int      &r_vahidx,
                  double   &r_val,  int      &r_validx)
  {
//Print(__FUNCTION__, ":", __LINE__, " Calculating Value Area...");
// Initialize output parameters
   r_vah = 0.0;
   r_vahidx = 0;
   r_val = 0.0;
   r_validx = 0;

   if(countps == 0 || ArrayRange(aprice_step,0) == 0)
     {
      Print(__FUNCTION__, ":", __LINE__, " No data in aprice_step for Value Area calculation.");
      return;
     }

   int    poc_idx  = UseVolumeProfile ? maxvolidx : maxtpoidx;      // Index of POC (TPO or Volume)
   int    data_col_idx = UseVolumeProfile ? VOLIDX : TPOIDX;        // Column index in aprice_step (VOLIDX or TPOIDX)
   double total_profile_data = UseVolumeProfile ? totalvol : totaltpo; // Total TPO or Volume

   if(poc_idx < 0 || poc_idx >= countps)
     {
      Print(__FUNCTION__, ":", __LINE__, " Warning: Invalid POC index (",poc_idx,") for Value Area calculation.");
      return;
     }
   if(total_profile_data <= 0)
     {
      Print(__FUNCTION__, ":", __LINE__, " Warning: Total profile data (TPO/Vol) is zero or negative for Value Area calculation.");
      return;
     }


// Calculate the target TPO/Volume for the Value Area
   double va_target_data  = (VATPOPercent/100.0) * total_profile_data;
   double accumulated_data = aprice_step[poc_idx][data_col_idx]; // Start with data at POC level

// Indices for expanding outwards from POC to find VA boundaries
   int    upper_offset = 1, last_upper_offset = 0; // Offset upwards from POC
   int    lower_offset = 1, last_lower_offset = 0; // Offset downwards from POC

// Loop to accumulate TPO/Volume outwards from POC until VA_target_data is reached
   while(accumulated_data < va_target_data)
     {
      double upper_level1_data = 0.0, lower_level1_data = 0.0;
      double upper_level2_data = 0.0, lower_level2_data = 0.0;

      // Get data from levels adjacent to current expansion boundary (1 step away)
      if(poc_idx - upper_offset >= 0)
         upper_level1_data = aprice_step[ poc_idx - upper_offset ][data_col_idx];
      if(poc_idx + lower_offset < countps)
         lower_level1_data = aprice_step[ poc_idx + lower_offset ][data_col_idx];

      // Get data from levels 2 steps away from current expansion boundary
      if(poc_idx - (upper_offset+1) >= 0)
         upper_level2_data = aprice_step[ poc_idx - (upper_offset+1) ][data_col_idx];
      if(poc_idx + (lower_offset+1) < countps)
         lower_level2_data = aprice_step[ poc_idx + (lower_offset+1) ][data_col_idx];

      // Check if VA target reached by adding just one of the adjacent levels
      // Prioritize adding the level with more data (TPO/Volume)
      if(upper_level1_data >= lower_level1_data)
        {
         if(accumulated_data + upper_level1_data >= va_target_data && upper_level1_data > 0)   // Check upper_level1_data > 0 to avoid infinite loop on zero-TPO levels
           {
            last_upper_offset = upper_offset;
            accumulated_data += upper_level1_data;
            break; // Target reached
           }
        }
      else // lower_level1_data > upper_level1_data
        {
         if(accumulated_data + lower_level1_data >= va_target_data && lower_level1_data > 0)
           {
            last_lower_offset = lower_offset;
            accumulated_data += lower_level1_data;
            break; // Target reached
           }
        }

      // If not reached, consider adding two levels (one up, one down, or two in one direction)
      // This part aims to expand more "balanced" or pick the direction with more data over two steps
      double data_if_expand_up_two_steps   = upper_level1_data + upper_level2_data;
      double data_if_expand_down_two_steps = lower_level1_data + lower_level2_data;

      if(data_if_expand_up_two_steps >= data_if_expand_down_two_steps)
        {
         // Expand upwards by two steps if possible, or one if at boundary
         if(poc_idx - upper_offset >= 0)
            accumulated_data += upper_level1_data;
         else { /* At array top */ }
         last_upper_offset = upper_offset; // Mark this level as included
         upper_offset++;

         if(accumulated_data >= va_target_data)
            break;

         if(poc_idx - upper_offset >= 0)
            accumulated_data += upper_level2_data;
         else { /* At array top */ }
         last_upper_offset = upper_offset; // Mark this level as included
         upper_offset++;
        }
      else // Expand downwards
        {
         if(poc_idx + lower_offset < countps)
            accumulated_data += lower_level1_data;
         else { /* At array bottom */ }
         last_lower_offset = lower_offset;
         lower_offset++;

         if(accumulated_data >= va_target_data)
            break;

         if(poc_idx + lower_offset < countps)
            accumulated_data += lower_level2_data;
         else { /* At array bottom */ }
         last_lower_offset = lower_offset;
         lower_offset++;
        }

      // Safety break: if offsets grow too large without reaching target (e.g., sparse data)
      if(upper_offset > countps && lower_offset > countps)
        {
         Print(__FUNCTION__, ":", __LINE__, " Warning: Value Area expansion offsets exceeded countps. VA might be entire profile.");
         // If target not met, VA might effectively be the whole profile range
         if(poc_idx - last_upper_offset < 0)
            last_upper_offset = poc_idx; // Cap at top of array
         if(poc_idx + last_lower_offset >= countps)
            last_lower_offset = countps - 1 - poc_idx; // Cap at bottom
         break;
        }
      if(poc_idx - upper_offset < 0 && poc_idx + lower_offset >= countps)
         break; // Reached both ends of profile

     } // end while (accumulated_data <= va_target_data)

// Set VAH/VAL indices and prices
   r_vahidx = poc_idx - last_upper_offset;
   r_validx = poc_idx + last_lower_offset;

// Ensure indices are within bounds
   if(r_vahidx < 0)
      r_vahidx = 0;
   if(r_validx >= countps)
      r_validx = countps - 1;
   if(r_vahidx > r_validx && countps > 0)    // Should not happen if logic is correct, but as safeguard
     {
      Print(__FUNCTION__,":",__LINE__," Warning: VAH index > VAL index. Setting to POC. VAHidx:", r_vahidx, " VALidx:", r_validx);
      r_vahidx = poc_idx;
      r_validx = poc_idx;
     }


   if(r_vahidx >=0 && r_vahidx < countps)
      r_vah = aprice_step[r_vahidx][PRICEIDX];
   else
      if(countps>0)
         r_vah = aprice_step[0][PRICEIDX];
   if(r_validx >=0 && r_validx < countps)
      r_val = aprice_step[r_validx][PRICEIDX];
   else
      if(countps>0)
         r_val = aprice_step[countps-1][PRICEIDX];

// Ensure VAH is actually higher than VAL (prices decrease with index)
   if(r_vah < r_val)
     {
      double temp = r_vah;
      r_vah = r_val;
      r_val = temp;
     }
//Print(__FUNCTION__, ":", __LINE__, " Value Area Calculated. VAH: ", r_vah, " (idx:", r_vahidx, "), VAL: ", r_val, " (idx:", r_validx, ")");
  }


//+------------------------------------------------------------------+
//| Draws the Value Area rectangle(s) and VAH/VAL lines.             |
//| INPUT:                                                           |
//|   startbar_datatf - int, starting bar on giDataTf for this profile|
//|   endbar_datatf   - int, ending bar on giDataTf for this profile  |
//|   ibar_proftf     - int, index of the profile (0=current)        |
//|   countps         - int, number of price steps in aprice_step    |
//|   aprice_step     - double[][], array with profile data          |
//|   vah             - double, Value Area High price                |
//|   vahidx          - int, index of VAH in aprice_step             |
//|   val             - double, Value Area Low price                 |
//|   validx          - int, index of VAL in aprice_step             |
//+------------------------------------------------------------------+
void drawValueArea(int    startbar_datatf, int    endbar_datatf, int    ibar_proftf,
                   int    countps, double &aprice_step[][3],
                   double vah,     int    vahidx,
                   double val,     int    validx)
  {
//Print(__FUNCTION__, ":", __LINE__, " Drawing Value Area for ibar_proftf: ", ibar_proftf);
   if(countps == 0 || ArrayRange(aprice_step,0) == 0 || vahidx < 0 || validx < 0 || vahidx >= countps || validx >= countps || vahidx > validx)
     {
      Print(__FUNCTION__, ":", __LINE__, " Invalid parameters for drawing Value Area for ibar_proftf: ", ibar_proftf);
      return;
     }

   datetime profile_period_start_time = iTime(NULL, giDataTf, startbar_datatf);
   datetime profile_period_end_time_for_va; // End time for VA rectangle // oes not appear to be used but leaving it.

   if(profile_period_start_time == 0)
     {
      Print(__FUNCTION__, ":", __LINE__, " Error: Could not get time for startbar_datatf ", startbar_datatf, " in drawValueArea.");
      return;
     }
   int      chart_startbar_idx = iBarShift(NULL, 0, profile_period_start_time);   // Bar index on current chart for profile start
   if(chart_startbar_idx == -1)
     {
      Print(__FUNCTION__, ":", __LINE__, " Error: Could not map startbar_datatf to chart bar for ibar_proftf: ", ibar_proftf);
      return;
     }

// Determine time extents for VA objects
   datetime dt_va_righmost_edge = Time[chart_startbar_idx]; // VA starts at the right edge of the profile
   datetime dt_va_leftmost_edge;

   if(endbar_datatf == 0 && ibar_proftf == 0)  // Current, forming profile
     {
      dt_va_leftmost_edge = Time[0] + 10*Period()*60; // Extend to the right from current time
     }
   else // Historical profile
     {
      // The VA for historical profiles should ideally align with the profile's actual time span on chart
      datetime profile_actual_end_time_on_chart;
      // If it's not the absolute current forming profile (ibar_proftf=0 and endbar_datatf=0),
      // its end time is the time of the end bar on data TF, or start of next profile TF period.
      if(ibar_proftf > 0 || (ibar_proftf == 0 && endbar_datatf !=0))     // Historical or completed current day before midnight
        {
         profile_actual_end_time_on_chart = iTime(NULL, giDataTf, endbar_datatf);
         // If using ProfileTF boundaries:
         // profile_actual_end_time_on_chart = iTime(NULL, giProfileTf, ibar_proftf -1);
         // Ensure this time is not 0
         if(profile_actual_end_time_on_chart == 0 && endbar_datatf > 0)    // Fallback if iTime fails for endbar_datatf
           {
            profile_actual_end_time_on_chart = iTime(NULL, giProfileTf, ibar_proftf -1);
           }
         if(profile_actual_end_time_on_chart == 0)    // Further fallback
           {
            profile_actual_end_time_on_chart = Time[iBarShift(NULL, 0, iTime(NULL, giDataTf, endbar_datatf))];
           }

        }
      else     // Should be covered by the first if, but as a safeguard for ibar_proftf == 0 and endbar_datatf == 0
        {
         profile_actual_end_time_on_chart = Time[0] + 10*Period()*60;
        }
      dt_va_leftmost_edge = profile_actual_end_time_on_chart;
     }


   double   lowest_price_in_profile = aprice_step[countps-1][PRICEIDX];
   int      argb[3]; // Array for RGB components of VAColor
   intToRGB(VAColor, argb);

// For the current forming profile, delete old VA objects before redrawing
   if(ibar_proftf == 0)
     {
      delObjs(gsPref + "#" + ibar_proftf + ".0.0.0.va.");  // Delete VA rectangle segments
      // VAH/VAL lines are typically updated, not deleted per segment, but could be if part of this prefix.
      // Original code had specific ObjectDelete commented out, delObjs with prefix is broader.
     }

   int      iclr_gradient_step = 0;   // Step for gradient color calculation
   double   price1_va = 0.0, price2_va = 0.0; // Prices for VA rectangle segments
   int      mid_va_idx    = vahidx + MathCeil((validx-vahidx)/2.0); // Midpoint index within Value Area range
   int      va_segment_idx = 0; // Counter for VA segment objects

// --- Draw Value Area rectangle(s) ---
   if(ShowValueArea)
     {
      // Iterate through price steps with giStep increment, only within the VA (vahidx to validx)
      for(int step_va_idx = vahidx; step_va_idx <= validx; step_va_idx += giStep)
        {
         price1_va = aprice_step[step_va_idx][PRICEIDX]; // Top price of this VA segment
         if(step_va_idx + giStep < countps && step_va_idx + giStep <= validx + giStep -1)     // validx + giStep -1 ensures it can reach VAL if VAL is not a multiple of giStep from VAH
           {
            price2_va = aprice_step[step_va_idx + giStep][PRICEIDX];
           }
         else
           {
            price2_va = val; // Ensure bottom of last segment is exactly VAL
           }
         if(step_va_idx == vahidx)
            price1_va = vah; // Ensure top of first segment is exactly VAH


         // The VA rectangle should start from the right edge of where the histogram bar *ends*
         // if ShowPriceHistogram is true. Otherwise, it starts from profile's right edge (dt_va_righmost_edge).
         datetime rect_right_edge = dt_va_righmost_edge;
         if(ShowPriceHistogram)
           {
            string histo_obj_name_tpo = gsPref + "#" + ibar_proftf + ".histotpo." + DoubleToStr(price1_va, fdigits);
            string histo_obj_name_vol = gsPref + "#" + ibar_proftf + ".histovol." + DoubleToStr(price1_va, fdigits);
            datetime time_from_tpo_histo = 0;
            datetime time_from_vol_histo = 0;

            if(ObjectFind(histo_obj_name_tpo) != -1)
               time_from_tpo_histo = ObjectGet(histo_obj_name_tpo, OBJPROP_TIME2);
            if(ObjectFind(histo_obj_name_vol) != -1)
               time_from_vol_histo = ObjectGet(histo_obj_name_vol, OBJPROP_TIME2);

            rect_right_edge = MathMax(time_from_tpo_histo, time_from_vol_histo);
            if(rect_right_edge == 0)
               rect_right_edge = dt_va_righmost_edge; // Fallback if histo objects not found/drawn
           }

         color current_va_color = VAColor;
         if(useGradientColorForValueArea)
           {
            current_va_color = RGB(argb[0]+iclr_gradient_step, argb[1]+iclr_gradient_step, argb[2]+iclr_gradient_step);
           }

         // Create rectangle segment for this part of VA
         createRect("#" + ibar_proftf + ".0.0.0.va." + va_segment_idx,
                    price1_va, rect_right_edge,
                    MathMax(price2_va, val), dt_va_leftmost_edge, // Ensure bottom is not below VAL
                    current_va_color);

         // Adjust color step for gradient effect
         if(step_va_idx < mid_va_idx)  // Approaching middle of VA from top
           {
            if(giProfileTf == PERIOD_MN1)
               iclr_gradient_step +=1;
            else
               if(giProfileTf == PERIOD_W1)
                  iclr_gradient_step +=2;
               else
                  iclr_gradient_step += 3;
           }
         else // Moving away from middle of VA towards bottom
           {
            if(giProfileTf == PERIOD_MN1)
               iclr_gradient_step -=1;
            else
               if(giProfileTf == PERIOD_W1)
                  iclr_gradient_step -=2;
               else
                  iclr_gradient_step -= 3;
           }
         // Ensure gradient step doesn't make colors too bright/dark (cap them)
         iclr_gradient_step = MathMax(-argb[0]+10, MathMin(255-argb[0]-10, iclr_gradient_step)); // Cap relative to Red
         iclr_gradient_step = MathMax(-argb[1]+10, MathMin(255-argb[1]-10, iclr_gradient_step)); // Cap relative to Green
         iclr_gradient_step = MathMax(-argb[2]+10, MathMin(255-argb[2]-10, iclr_gradient_step)); // Cap relative to Blue


         va_segment_idx++;
        } // end for (step_va_idx)
     } // end if (ShowValueArea)

// --- Draw VAH and VAL lines ---
   if(ShowVAHVALLines)
     {
      // Ensure dt_va_leftmost_edge is sensible if historical
      if(dt_va_leftmost_edge < Time[chart_startbar_idx] && ibar_proftf > 0)
        {
         // For historical, VALines should ideally span the profile's actual duration
         // dt_va_leftmost_edge might be from iTime(..., ibar_proftf-1) which is start of NEXT profile
         // So it should be correct. If it needs to extend like current, uncomment below.
         // dt_va_leftmost_edge = Time[0] + (10*Period()*60);
        }
      else
         if(dt_va_leftmost_edge == 0 && ibar_proftf == 0)    // Current profile, not extended yet
           {
            dt_va_leftmost_edge = Time[0] + (10*Period()*60);
           }


      int line_width = ShowValueArea ? 1 : 2; // Thicker lines if VA rectangle is hidden

      // VAH Line
      createTl("#" + ibar_proftf + ".0.0.0.vah",
               dt_va_righmost_edge, vah, // Start time (right edge of profile), VAH price
               dt_va_leftmost_edge, vah, // End time (left edge or extended), VAH price
               VALinesColor, STYLE_SOLID, line_width);
      // VAL Line
      createTl("#" + ibar_proftf + ".0.0.0.val",
               dt_va_righmost_edge, val, // Start time, VAL price
               dt_va_leftmost_edge, val, // End time, VAL price
               VALinesColor, STYLE_SOLID, line_width);
     }
//Print(__FUNCTION__, ":", __LINE__, " Finished drawing Value Area for ibar_proftf: ", ibar_proftf);
  }

//+------------------------------------------------------------------+
//| Adds a specified character to the beginning or end of a string   |
//| until the string reaches a maximum length.                       |
//| INPUT:                                                           |
//|   str         - string, the original string                      |
//|   tchar       - string, the character to add                     |
//|   maxlength   - int, the target maximum length of the string     |
//|   atbeginning - bool, if true, add to beginning, else to end   |
//| RETURN: string - the modified string.                            |
//+------------------------------------------------------------------+
string addStr(string str, string tchar, int maxlength, bool atbeginning = true)
  {
   string original_str = str; // Keep original for modification
   int chars_to_add = maxlength - StringLen(original_str);
   for(int i=0; i<chars_to_add; i++)
     {
      if(atbeginning)
         original_str = tchar + original_str;
      else
         original_str = original_str + tchar;
     }
   return(original_str);
  }

//+------------------------------------------------------------------+
//| Creates or updates a rectangle object on the chart.              |
//| INPUT:                                                           |
//|   objname - string, unique part of the object name               |
//|   p1      - double, price coordinate of the first corner         |
//|   t1      - datetime, time coordinate of the first corner        |
//|   p2      - double, price coordinate of the second corner        |
//|   t2      - datetime, time coordinate of the second corner       |
//|   clr     - color, color of the rectangle                        |
//|   back    - bool, if true, draw in background, else foreground |
//+------------------------------------------------------------------+
void createRect(string objname, double p1, datetime t1, double p2, datetime t2, color clr, bool back=true)
  {
   string full_objname = gsPref + objname;
   if(ObjectFind(full_objname) != 0) // Object does not exist, create it
     {
      ObjectCreate(full_objname, OBJ_RECTANGLE, 0, t1, p1, t2, p2); // Note: MQL4 OBJ_RECTANGLE takes (time1, price1, time2, price2)
     }                                                                  // The original had 0,0,0,0,0 which are ignored.
// Set properties regardless of creation or existence (for updates)
   ObjectSet(full_objname, OBJPROP_TIME1,  t1);
   ObjectSet(full_objname, OBJPROP_PRICE1, p1);
   ObjectSet(full_objname, OBJPROP_TIME2,  t2);
   ObjectSet(full_objname, OBJPROP_PRICE2, p2);
   ObjectSet(full_objname, OBJPROP_COLOR,  clr);
   ObjectSet(full_objname, OBJPROP_BACK,   back);
   ObjectSet(full_objname, OBJPROP_FILL, true); // Ensure rectangle is filled, common for VA/Histo
  }

//+------------------------------------------------------------------+
//| Creates or updates an arrow object on the chart.                 |
//| INPUT:                                                           |
//|   objname - string, unique part of the object name               |
//|   p1      - double, price coordinate for the arrow anchor        |
//|   t1      - datetime, time coordinate for the arrow anchor       |
//|   ac      - int, arrow code (Wingdings font character code)      |
//|   clr     - color, color of the arrow                            |
//+------------------------------------------------------------------+
void createArw(string objname, double p1, datetime t1, int arrow_code, color clr)
  {
   string full_objname = gsPref + objname;
   if(ObjectFind(full_objname) != 0)
     {
      ObjectCreate(full_objname, OBJ_ARROW, 0, t1, p1); // Subwindow 0, time1, price1
     }
   ObjectSet(full_objname, OBJPROP_TIME1,      t1);
   ObjectSet(full_objname, OBJPROP_PRICE1,     p1);
   ObjectSet(full_objname, OBJPROP_ARROWCODE,  arrow_code);
   ObjectSet(full_objname, OBJPROP_COLOR,      clr);
   ObjectSet(full_objname, OBJPROP_WIDTH,      1); // Default width
  }

//+------------------------------------------------------------------+
//| Creates or updates a text object on the chart.                   |
//| INPUT:                                                           |
//|   name    - string, unique part of the object name               |
//|   t       - datetime, time coordinate for the text anchor        |
//|   p       - double, price coordinate for the text anchor         |
//|   text    - string, the text to display                          |
//|   size    - int, font size                                       |
//|   font    - string, font name                                    |
//|   c       - color, text color                                    |
//+------------------------------------------------------------------+
void createText(string name, datetime t, double p, string text_to_display,
                int size=8, string font="Arial", color c=White)
  {
   string full_objname = gsPref + name;
   if(ObjectFind(full_objname) != 0)  // Object does not exist
     {
      ObjectCreate(full_objname, OBJ_TEXT, 0, t, p);
     }
   ObjectSet(full_objname, OBJPROP_TIME1,  t);
   ObjectSet(full_objname, OBJPROP_PRICE1, p);
   ObjectSetText(full_objname, text_to_display, size, font, c);
   ObjectSet(full_objname, OBJPROP_ANCHOR, ANCHOR_LEFT);     // Common setting for text labels
  }

//+------------------------------------------------------------------+
//| Creates or updates a trendline object on the chart.              |
//| INPUT:                                                           |
//|   tlname  - string, unique part of the object name               |
//|   t1      - datetime, time coordinate of the first point         |
//|   v1      - double, price coordinate of the first point          |
//|   t2      - datetime, time coordinate of the second point        |
//|   v2      - double, price coordinate of the second point         |
//|   tlColor - color, color of the trendline                        |
//|   style   - int, line style (e.g., STYLE_SOLID)                  |
//|   width   - int, line width                                      |
//|   back    - bool, if true, draw in background                  |
//|   desc    - string, object description (tooltip)                 |
//+------------------------------------------------------------------+
void createTl(string tlname, datetime t1, double v1, datetime t2, double v2,
              color tlColor, int style = STYLE_SOLID, int width = 1, bool back=true, string desc="")
  {
   string full_objname = gsPref + tlname;
   if(ObjectFind(full_objname) != 0) // Object does not exist
     {
      ObjectCreate(full_objname, OBJ_TREND, 0, t1, v1, t2, v2);
     }
   else // Object exists, move its points
     {
      ObjectMove(full_objname, 0, t1, v1); // Move point 0 (first point)
      ObjectMove(full_objname, 1, t2, v2); // Move point 1 (second point)
     }
   ObjectSet(full_objname, OBJPROP_COLOR, tlColor);
   ObjectSet(full_objname, OBJPROP_RAY,   false); // Ensure it's a line segment, not a ray
   ObjectSet(full_objname, OBJPROP_STYLE, style);
   ObjectSet(full_objname, OBJPROP_WIDTH, width);
   ObjectSet(full_objname, OBJPROP_BACK,  back);
   if(StringLen(desc) > 0)
      ObjectSetText(full_objname, desc, 8, "Arial", tlColor); // Set description if provided
  }

//+------------------------------------------------------------------+
//| Checks if a new bar has formed on the `giProfileTf` timeframe.   |
//| RETURN: bool - true if a new profile bar started, false otherwise.|
//+------------------------------------------------------------------+
bool newBarProfileTf()
  {
   static datetime last_profile_bar_time = 0; // Stores the start time of the last known profile bar
   datetime current_profile_bar_time = 0;     // Start time of the current profile bar based on Time[0]

   string str_current_date = ""; // Temporary for D1 calculation with DayStartHour
   int one_profile_period_seconds = giProfileTf*60; // Duration of one profile period in seconds

   switch(giProfileTf)
     {
      case PERIOD_D1: // Daily profile with custom DayStartHour handling
         str_current_date = TimeToStr(Time[0],TIME_DATE); // Get current date "YYYY.MM.DD"
         current_profile_bar_time = StrToTime(str_current_date) + (DayStartHour * 3600); // Add custom start hour in seconds
         // If current chart time is before today's DayStartHour, the current profile bar started yesterday at DayStartHour
         if(Time[0] < current_profile_bar_time)
           {
            current_profile_bar_time -= one_profile_period_seconds; // Subtract one day
           }
         break;
      default: // For W1, MN1, H4, H1, M30, M15, M5
         // iBarShift(NULL, giProfileTf, Time[0]) gives the index of the current giProfileTf bar
         // iTime then converts this index back to the start time of that bar.
         current_profile_bar_time = iTime(NULL, giProfileTf, iBarShift(NULL, giProfileTf, Time[0]));
         break;
     }

   if(last_profile_bar_time != current_profile_bar_time)
     {
      last_profile_bar_time = current_profile_bar_time;
      //Print(__FUNCTION__, ":", __LINE__, " New ProfileTF bar detected. Time: ", TimeToString(current_profile_bar_time));
      return (true);
     }

   return(false);
  }

//+------------------------------------------------------------------+
//| Checks if a new bar has formed on the current chart's timeframe. |
//| RETURN: bool - true if new chart bar, false otherwise.           |
//+------------------------------------------------------------------+
bool newBar()
  {
   static datetime last_bar_on_chart_time = 0; // Stores Time[0] of the last known chart bar
   datetime current_bar_on_chart_time = Time[0]; // Current bar's open time

   if(last_bar_on_chart_time != current_bar_on_chart_time)
     {
      last_bar_on_chart_time = current_bar_on_chart_time;
      return (true);
     }
   return(false);
  }

//+------------------------------------------------------------------+
//| Deletes chart objects created by this indicator instance.        |
//| Can delete all or only those matching a sub-prefix.              |
//| INPUT:                                                           |
//|   s_filter - string, if provided, only deletes objects whose names|
//|              start with `gsPref` + `s_filter`. If empty, deletes |
//|              all objects starting with `gsPref`.                 |
//+------------------------------------------------------------------+
void delObjs(string s_filter="")
  {
   int total_objects = ObjectsTotal(0, -1, -1); // Get total objects on main chart
   string full_filter_prefix = gsPref;
   if(StringLen(s_filter) > 0)
     {
      full_filter_prefix = gsPref + s_filter;
     }

   string obj_name = "";
// Loop backwards as deleting objects shifts indices
   for(int cnt = total_objects - 1; cnt >= 0; cnt--)
     {
      obj_name = ObjectName(cnt);
      // Check if the object name starts with the specified prefix
      if(StringFind(obj_name, full_filter_prefix, 0) == 0)  // Found at the beginning
        {
         ObjectDelete(obj_name);
        }
     }
  }

//+------------------------------------------------------------------+
//| Converts Red, Green, and Blue integer values to a single color   |
//| integer value used by MQL4.                                      |
//| INPUT:                                                           |
//|   red_value   - int (0-255)                                      |
//|   green_value - int (0-255)                                      |
//|   blue_value  - int (0-255)                                      |
//| RETURN: int - combined color value.                              |
//+------------------------------------------------------------------+
int RGB(int red_value,int green_value,int blue_value)
  {
// Ensure values are within the 0-255 range
   if(red_value<0)
      red_value   = 0;
   if(red_value>255)
      red_value   = 255;
   if(green_value<0)
      green_value = 0;
   if(green_value>255)
      green_value = 255;
   if(blue_value<0)
      blue_value  = 0;
   if(blue_value>255)
      blue_value  = 255;

// Combine into a single color value (BGR order in memory)
   return(red_value + (green_value << 8) + (blue_value << 16));
  }

//+------------------------------------------------------------------+
//| Converts a single MQL4 color integer value to its Red, Green,    |
//| and Blue components.                                             |
//| INPUT:                                                           |
//|   clr     - int, the MQL4 color value                            |
//| OUTPUT:                                                          |
//|   argb    - int[] (by ref), array to store R, G, B values.       |
//|             argb[0]=Red, argb[1]=Green, argb[2]=Blue.            |
//+------------------------------------------------------------------+
void intToRGB(int clr_val, int &argb[])
  {
   if(ArraySize(argb) < 3)
      ArrayResize(argb, 3); // Ensure array is large enough

   argb[0] =  clr_val & 0xFF;          // Red component
   argb[1] = (clr_val >> 8) & 0xFF;   // Green component
   argb[2] = (clr_val >> 16) & 0xFF;  // Blue component
  }
//+------------------------------------------------------------------+

/* Original suggestions block - retained for reference
sugestions v1.31
http://www.forexfactory.com/showpost.php?p=4432129&postcount=629
@mima
Very good, I like that histogram can be false/true...VA is 1st standard deviation...so there is need for 2nd , 3rd and extremes(excesses)...Hopefully it will be in next revision. Thank you.

http://www.forexfactory.com/showpost.php?p=4432111&postcount=628
@kave
PS: One thing i notice that if the POC & VPC is align the POC overlay onto the VPC as shown here, (those 2 POC of 23rd & 24th).
Since the 24th Feb qualifies as a VPC, is it possible let the VPC line to be overlayed on top instead??

http://www.forexfactory.com/showpost.php?p=4433083&postcount=634
@jamie
One comment, for the volume based profile is it possible to reduce the amplitude of the profile so that it doesn't extend so far to the right?
*/
//+------------------------------------------------------------------+
