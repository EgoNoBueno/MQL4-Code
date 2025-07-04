//+------------------------------------------------------------------+
//|                                      Three Colour MACD V1p10.mq4 |
//|                            Original Author: Nikolay Kositsin     |
//+------------------------------------------------------------------+

#property version "1.10"

/*

## Summary of Changes Made to Your MQL4 Code in ver 1p10

I've refined your "Three Colour MACD" indicator code to address the
issues preventing its display and improve its robustness.
Here's a summary of the key modifications:

### Core Issue Resolution

* **`IndicatorBuffers` Mismatch Corrected**:
The `#property indicator_buffers` was set to 5, but your `init()` function used 6 buffers.
I've updated the `#property` to **`#property indicator_buffers 6`** to match the actual
buffer usage (`ind_buffer1` through `ind_buffer6`).
* **Corrected `SetIndexBuffer` Logic**: The `SetIndexBuffer` checks in
`init()` were using `&&` (AND), meaning the `Print` statement would only
trigger if *all* calls failed. I've changed them to `||` (OR), so if *any*
buffer fails to set, the error message will be printed, making debugging easier.
* **Removed Redundant `SetIndexStyle` Calls**:
The `SetIndexStyle` functions were unnecessarily repeated in the `start()` function.
These calls belong solely in `init()`, and I've removed them from `start()`
to prevent potential conflicts or redundant processing.
* **Improved `SetIndexDrawBegin`**: The original `SetIndexDrawBegin`
values could lead to drawing issues or out-of-bounds errors, especially with
`Bars-CountBars`. I've simplified them to **`SetIndexDrawBegin(index, 0)`** for
 all buffers. This ensures the indicator attempts to draw from the beginning of
 the available data, making it more likely to display.

### Code Robustness & Clarity

* **Unique Loop Counter Variables**: All `for` loop counter variables
 (`i`, `iMACD`, `iSignal`, `iHistogram`) are now unique to prevent potential
 variable shadowing or unintended interactions, enhancing code clarity and safety.
* **Backward Loop Iteration**: Indicator calculations in MQL4 are often more
 robust and efficient when performed by iterating backward from the
 `limit - 1` to `0`. I've implemented this pattern for all main calculation loops (`iMACD`, `iSignal`, `iHistogram`).
* **Bounds Checking for `i+1`**: Specifically for the `minuse` calculation,
which accesses `ind_buffer6[iHistogram+1]`, I've added a check
(`if (iHistogram < Bars - 1)`) to prevent accessing an out-of-bounds
index for the very last bar, making the code safer.
* **Unused Variable Removed**: The variable `Zml` was declared but never
used, so I've removed it to keep the code clean.
* **Minor Comments and Formatting**: I've added or adjusted comments
to better explain sections of the code and improved general formatting for readability.

These changes should resolve the display issues you were encountering
and make your "Three Colour MACD" indicator more stable and reliable.
Remember to recompile the code in MetaEditor (F7) after making these changes.
EgoNoBueno
*/
//---- indicator settings
#property  indicator_separate_window
#property  indicator_buffers 6 // Changed from 5 to 6 to match usage
#property  indicator_color1  clrForestGreen //MACD +
#property  indicator_color2  clrRed // MACD -
#property  indicator_color3  clrGray //MACD Zero
#property  indicator_color4  clrGold// MACD Signal
#property  indicator_color5  clrBlack
// You might consider adding indicator_color6 if ind_buffer6 was directly drawn
// but it's used for calculation, so it's not strictly necessary here.

//---- indicator parameters
extern int FastEMA=13;
extern int SlowEMA=50;
extern int SignalSMA=4;
extern int CountBars=5000;
extern int Line=2;
extern double  Zero_level=0.0;
//---- indicator buffers
double    ind_buffer1[]; // MACD+
double    ind_buffer2[]; // MACD-
double    ind_buffer3[]; // MACD0 (Zero crossing)
double    ind_buffer4[]; // Signal Line
double    ind_buffer5[]; // Zero Line
double    ind_buffer6[]; // Raw MACD for calculations

double minuse;
double Vol;
// double Zml; // Zml is declared but not used, can be removed.
double Color1;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int init()
  {
//---- indicator buffers mapping
   IndicatorBuffers(6); // This is correct for 6 buffers.
   if(!SetIndexBuffer(0,ind_buffer1) || // Changed '&&' to '||' for proper error checking
      !SetIndexBuffer(1,ind_buffer2) ||
      !SetIndexBuffer(2,ind_buffer3) ||
      !SetIndexBuffer(3,ind_buffer4) ||
      !SetIndexBuffer(4,ind_buffer5) ||
      !SetIndexBuffer(5,ind_buffer6))
      Print("cannot set indicator buffers!");
//---- drawing settings

   SetIndexStyle(0,DRAW_HISTOGRAM, STYLE_SOLID, Line);
   SetIndexStyle(1,DRAW_HISTOGRAM, STYLE_SOLID, Line); // Uses indicator_color2 by default
   SetIndexStyle(2,DRAW_HISTOGRAM, STYLE_SOLID, Line); // Uses indicator_color3 by default
   SetIndexStyle(3,DRAW_LINE, STYLE_SOLID,4);        // Uses indicator_color4 by default
   SetIndexStyle(4,DRAW_LINE, STYLE_SOLID,4);     // Uses indicator_color5 by default

// Simplified SetIndexDrawBegin to ensure all data is potentially drawn
   SetIndexDrawBegin(0,0);
   SetIndexDrawBegin(1,0);
   SetIndexDrawBegin(2,0);
   SetIndexDrawBegin(3,0);
   SetIndexDrawBegin(4,0);
// SetIndexShift for buffer 4 (zero line) is kept as it might be intended,
// but typically a zero line is not shifted. Review if this is truly desired.
   SetIndexShift(4,100);

   IndicatorDigits(MarketInfo(Symbol(),MODE_DIGITS)+1);

//---- name for DataWindow and indicator subwindow label
   IndicatorShortName("MACD("+FastEMA+","+SlowEMA+","+SignalSMA+")");
   SetIndexLabel(0,"MACD+");
   SetIndexLabel(1,"MACD-");
   SetIndexLabel(2,"MACD0");
   SetIndexLabel(3,"Signal");
   SetIndexLabel(4,"Zero");
//---- initialization done
   return(0);
  }
//+------------------------------------------------------------------+
//| Moving Averages Convergence/Divergence                           |
//+------------------------------------------------------------------+
int start()
  {
// Removed SetIndexStyle calls from start(), as they belong in init().

   int limit;
   int counted_bars=IndicatorCounted();
//---- check for possible errors
   if(counted_bars<0)
      return(-1);
//---- last counted bar will be recounted
   if(counted_bars>0)
      counted_bars--;
   limit=Bars-counted_bars;

// Ensure limit is not negative or zero if Bars < counted_bars
   if(limit <= 0)
      return(0);

//---- macd counted in the 6th buffer (ind_buffer6)
// Iterate backwards for safety and efficiency in MQL4
   for(int iMACD = limit - 1; iMACD >= 0; iMACD--)
     {
      ind_buffer6[iMACD] = iMA(NULL, 0, FastEMA, 0, MODE_EMA, PRICE_CLOSE, iMACD) -
                           iMA(NULL, 0, SlowEMA, 0, MODE_EMA, PRICE_CLOSE, iMACD);
     }

//---- signal line counted in the 4th buffer (ind_buffer4)
   for(int iSignal = limit - 1; iSignal >= 0; iSignal--)
     {
      ind_buffer4[iSignal] = iMAOnArray(ind_buffer6, Bars, SignalSMA, 0, MODE_SMA, iSignal);
     }

//---- Three Colour MACD mapping and Zero Line
   for(int iHistogram = limit - 1; iHistogram >= 0; iHistogram--)
     {
      ind_buffer5[iHistogram] = Zero_level; // Zero line

      // Ensure we don't go out of bounds when accessing iHistogram+1
      if(iHistogram < Bars - 1)
        {
         Vol = ind_buffer6[iHistogram];
         minuse = Vol - ind_buffer6[iHistogram+1]; // Compare current MACD with previous

         if(minuse > 0.0)
           {
            ind_buffer1[iHistogram] = Vol; // Green (MACD rising)
            ind_buffer2[iHistogram] = 0.0;
            ind_buffer3[iHistogram] = 0.0;
           }
         else
            if(minuse < 0.0)
              {
               ind_buffer1[iHistogram] = 0.0;
               ind_buffer2[iHistogram] = Vol; // Red (MACD falling)
               ind_buffer3[iHistogram] = 0.0;
              }
            else     // minuse == 0.0
              {
               ind_buffer1[iHistogram] = 0.0;
               ind_buffer2[iHistogram] = 0.0;
               ind_buffer3[iHistogram] = Vol; // Grey (MACD unchanged)
              }
        }
      else
        {
         // For the most recent bar (iHistogram == Bars - 1), there's no iHistogram+1.
         // You might choose to handle this differently. For now, set to zero,
         // or perhaps just assign Vol to one of the buffers based on Vol's sign.
         ind_buffer1[iHistogram] = 0.0;
         ind_buffer2[iHistogram] = 0.0;
         ind_buffer3[iHistogram] = 0.0;
         // Alternative for the last bar (if desired):
         // if (ind_buffer6[iHistogram] > 0) ind_buffer1[iHistogram] = ind_buffer6[iHistogram];
         // else if (ind_buffer6[iHistogram] < 0) ind_buffer2[iHistogram] = ind_buffer6[iHistogram];
         // else ind_buffer3[iHistogram] = ind_buffer6[iHistogram];
        }
     }
//---- done
   return(0);
  }
//+------------------------------------------------------------------+
