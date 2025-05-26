//+------------------------------------------------------------------+
//|                             Structured MACD Entry.mq4            |
//|                  Expert Advisor for 87% Win Rate Strategy        |
//|                                                  Ego No Bueno    |
//+------------------------------------------------------------------+
#property copyright "EgoNoBueno"
#property link      "https://www.forexfactory.com/egonobueno"
#property version   "1.04" // Version updated for __LINE__ directive
#property strict
// Based off Trade Rush Video:
//Not meant for live trading. Educational only.

#include <stdlib.mqh>
#include <stderror.mqh>

//--- Input Parameters
extern string InpComment             = "Structured MACD entry";
extern int    InpBaseMagicNumber     = 654321;
extern int    InpTrendEMATF          = PERIOD_H1;
extern int    InpTrendEMAPeriod      = 150;
extern int    InpMACDFast            = 12;
extern int    InpMACDSlow            = 55;
extern int    InpMACDSignal          = 8;
extern double InpStopLossBufferPips  = 5.0;
extern double InpMinPriceImprovePips = 10.0;

//--- Risk & Reward Ratios
extern double InpRR_Entry1_2         = 0.25;
extern double InpRR_Entry3_Final     = 0.5;
extern double InpRR_FarAverage       = 0.5;

//--- Position Sizing
enum ENUM_SIZING_MODE
  {
   FixedLot,
   PercentRiskEqual,
   PercentRiskCompounding
  };
extern ENUM_SIZING_MODE InpSizingMode = PercentRiskCompounding;
extern double InpFixedLotSize      = 0.01;
extern double InpRisk_Entry1       = 0.5;
extern double InpRisk_Entry2       = 0.5;
extern double InpRisk_Entry3       = 0.5;
extern bool   UseUnifiedTurtleSeriesRisk      = true;
extern double InpUnifiedTurtleSeriesRiskPercent = 2.0;

//--- Trade Management
extern int    InpSlippage          = 30;

//--- Virtual SL/TP Settings
input group "Virtual Stops & Targets"
extern bool   UseVirtualSLTP              = true;
extern int    InpVslBrokerSlBufferPips    = 5;
extern int    InpVtpBrokerTpBufferPips    = 3;
extern color  InpVSLLineColor             = clrMagenta;
extern color  InpVTPLineColor             = clrBlue;
extern int    InpVSLTPLineStyle           = STYLE_DOT;
extern int    InpVSLTPLineWidth           = 1;

//--- Integrated Function Inputs
extern int    InTradeVisualSpeed            = 100000000;
extern int    OutOfTradeTesterThrottleSpeed = 1000000;
extern double MaxAllowedSpreadPoints        = 2.0;

// Trading Hours Filter
extern bool EnableTradingHoursFilter      = true;
extern int  TradingStartMinute            = 5;
extern int  TradingStartHour              = 0;
extern int  TradingEndHour                = 23;
extern bool AllowSundayTrading            = false;
extern bool AllowMondayTrading            = true;
extern bool AllowTuesdayTrading           = true;
extern bool AllowWednesdayTrading         = true;
extern bool AllowThursdayTrading          = true;
extern bool AllowFridayTrading            = true;
extern bool AllowSaturdayTrading          = false;

//--- Global Variables
bool     isSeriesActive = false;
int      entriesInSeries = 0;
int      ticketEntry1 = 0, ticketEntry2 = 0, ticketEntry3 = 0;
double   commonStopLoss = 0.0;
int      seriesDirection = -1;
datetime seriesStartTime;
double   pipValueInPoints;
int      slippagePoints;
static string EANameHUD = "Three Tries EA (VSL)";
int      g_brokerGmtOffset = 0;
double   g_currentSpreadPoints = 0.0, g_highestSpreadPoints = 0.0, g_lowestSpreadPoints = 999999.9;
double   g_totalSpreadPoints = 0.0;
long     g_spreadTickCount = 0;
double   g_averageSpreadPoints = 0.0;
double   g_effectiveMaxSpread = 0.0;
int      g_effectiveTradingEndHour = 23;
static datetime g_lastOrderSendTime = 0;
static ulong    g_lastOrderSelectDurationMs = 0;
int      g_totalTrades = 0, g_winningTrades = 0, g_losingTrades = 0;
double   g_totalProfitLossCurrency = 0.0, g_totalProfitLossPips = 0.0;
#define DAILY_CLOSE_HOUR 16
#define DAILY_CLOSE_MINUTE 55
int EA_MagicNumber = 0;
double   virtualStopLossLevel_Series = 0.0;
double   virtualTakeProfitLevel_Basket = 0.0;
string   VSL_LineName_Base = "VSL_TT_";
string   VTP_LineName_Base = "VTP_TT_";
string   currentVSLLineName = "";
string   currentVTPLineName = "";

// Forward declarations
void ResetSeriesState();
void UpdateBasketTakeProfit();
bool ManageVirtualExits();

//+------------------------------------------------------------------+
//| Generate Magic Number                                            |
//+------------------------------------------------------------------+
int GenerateMagicNumber(int p_baseNum)
  {
   string currentSymbol = Symbol();
   long symbolValue = 0;
   for(int i = 0; i < StringLen(currentSymbol); i++)
     {
      symbolValue = (symbolValue * 31 + StringGetCharacter(currentSymbol, i)) % 2147483647;
     }
   long magicNumberLong = (long)p_baseNum * 10007 + symbolValue + Period();
   int magicNumberInt = (int)(MathAbs(magicNumberLong) % 2147483647);
   if(magicNumberInt == 0)
     {
      magicNumberInt = 1234567;
     }
   return(magicNumberInt);
  }

//+------------------------------------------------------------------+
//| Draw or Update Horizontal Line                                   |
//+------------------------------------------------------------------+
void DrawUpdateLine(string name, double level, color lineColor, int lineStyle, int lineWidth)
  {
   if(name == "" || level <= 0)
      return;
   if(ObjectFind(name) == -1)
     {
      if(!ObjectCreate(name, OBJ_HLINE, 0, 0, level))
        { Print(__LINE__, ", Error creating HLine '", name, "': ", ErrorDescription(GetLastError())); return; }
     }
   else
     {
      if(!ObjectSetDouble(0, name, OBJPROP_PRICE1, level)) {}
     }
   ObjectSetInteger(0, name, OBJPROP_COLOR, lineColor);
   ObjectSetInteger(0, name, OBJPROP_STYLE, lineStyle);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, lineWidth);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   string lineDesc = StringSubstr(name, StringLen(VSL_LineName_Base));
   if(StringFind(name, VSL_LineName_Base,0) == 0)
      lineDesc = "VSL";
   else
      if(StringFind(name, VTP_LineName_Base,0) == 0)
         lineDesc = "VTP";
   ObjectSetString(0, name, OBJPROP_TEXT, " "+lineDesc + ": " + DoubleToString(level,Digits));
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
  }

//+------------------------------------------------------------------+
//| Delete Horizontal Line                                           |
//+------------------------------------------------------------------+
void DeleteLine(string name)
  {
   if(name != "" && ObjectFind(0, name) != -1)
      ObjectDelete(name);
  }

//+------------------------------------------------------------------+
//| Calculate Broker's GMT Offset                                    |
//+------------------------------------------------------------------+
int CalculateGMTOffset()
  {
   return((int)(TimeCurrent() - TimeGMT()) / 3600);
  }

//+------------------------------------------------------------------+
//| Monitor Spread                                                   |
//+------------------------------------------------------------------+
void MonitorSpread()
  {
   RefreshRates();
   double csRaw = Ask-Bid;
   if(csRaw<0||Bid<=0||Ask<=0||Point<=0)
     {
      g_currentSpreadPoints=-1;
      return;
     }
   g_currentSpreadPoints=NormalizeDouble(csRaw/Point,1);
   if(g_currentSpreadPoints>g_highestSpreadPoints)
      g_highestSpreadPoints=g_currentSpreadPoints;
   if(g_currentSpreadPoints>=0&&g_currentSpreadPoints<g_lowestSpreadPoints)
      g_lowestSpreadPoints=g_currentSpreadPoints;
   g_spreadTickCount++;
   if(g_currentSpreadPoints>=0)
      g_totalSpreadPoints+=g_currentSpreadPoints;
   if(g_spreadTickCount>0&&g_totalSpreadPoints>0)
      g_averageSpreadPoints=NormalizeDouble(g_totalSpreadPoints/g_spreadTickCount,1);
   else
      if(g_spreadTickCount>0)
         g_averageSpreadPoints=0;
  }

//+------------------------------------------------------------------+
//| Period To String (for HUD)                                       |
//+------------------------------------------------------------------+
string PeriodSecondsToTFString(int secs)
  {
   if(secs >= 1728000*1.5)
      return "MN1";
   if(secs >= 604800)
      return "W1";
   if(secs >= 86400)
      return "D1";
   if(secs >= 14400)
      return "H4";
   if(secs >= 3600)
      return "H1";
   if(secs >= 1800)
      return "M30";
   if(secs >= 900)
      return "M15";
   if(secs >= 300)
      return "M5";
   if(secs >= 60)
      return "M1";
   return "TF("+IntegerToString(secs / 60)+")";
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string PeriodIntegerToString(int pVal)
  {
   switch(pVal)
     {
      case PERIOD_M1:
         return "M1";
      case PERIOD_M5:
         return "M5";
      case PERIOD_M15:
         return "M15";
      case PERIOD_M30:
         return "M30";
      case PERIOD_H1:
         return "H1";
      case PERIOD_H4:
         return "H4";
      case PERIOD_D1:
         return "D1";
      case PERIOD_W1:
         return "W1";
      case PERIOD_MN1:
         return "MN1";
      case 0:
         return PeriodSecondsToTFString(PeriodSeconds(0));
      default:
         return "TF("+IntegerToString(pVal)+")";
     }
  }
//+------------------------------------------------------------------+
//| Calculate Take Profit Level                                      |
//+------------------------------------------------------------------+
double CalculateTakeProfit(double ePrice,double sLoss,int oType,double rrR)
  {
   double slDist=MathAbs(ePrice-sLoss);
   double tpDist=slDist*rrR;
   double tpPrice=0;
   if(oType==OP_BUY)
      tpPrice=ePrice+tpDist;
   else
      if(oType==OP_SELL)
         tpPrice=ePrice-tpDist;
   return(NormalizeDouble(tpPrice,Digits));
  }

//+------------------------------------------------------------------+
//| Calculate Lot Size                                               |
//+------------------------------------------------------------------+
double CalculateLotSize(double slLvl, int oType, double rPcnt)
  {
   if(InpSizingMode==FixedLot)
      return(NormalizeDouble(InpFixedLotSize,2));
   if(rPcnt<=0)
      return(0.0);
   double bal=AccountBalance(),rAmt=bal*(rPcnt/100.0),cPrice=(oType==OP_BUY)?Ask:Bid;
   double slDistPts_price=MathAbs(cPrice-slLvl);
   if(slDistPts_price<MarketInfo(Symbol(),MODE_STOPLEVEL)*Point+Point*0.1)
     { Print(__LINE__, ", SL dist too small: ",DoubleToString(slDistPts_price/Point,1)," points."); return(0.0); }
   double tkVal=MarketInfo(Symbol(),MODE_TICKVALUE),lots=0;
   if(tkVal<=0||Point<=0)
     {
      Print(__LINE__, ", LotCalc Err: TickVal/Point zero. TV:",tkVal," P:",Point);
      return 0.0;
     }
   double lossPerLotPerPt=tkVal;
   if(lossPerLotPerPt<=0)
     {
      Print(__LINE__, ", LotCalc Err: lossPerLotPerPt zero. BaseTV:",MarketInfo(Symbol(),MODE_TICKVALUE));
      return 0.0;
     }
   double totLossPerLot=(slDistPts_price/Point)*lossPerLotPerPt;
   if(totLossPerLot<=0)
     {
      Print(__LINE__, ", LotCalc Err: totLossPerLot zero. SL pts:",DoubleToString(slDistPts_price/Point,1)," TV_used:",DoubleToString(lossPerLotPerPt,5));
      return(0.0);
     }
   lots=rAmt/totLossPerLot;
   double minL=MarketInfo(Symbol(),MODE_MINLOT),maxL=MarketInfo(Symbol(),MODE_MAXLOT),lotStp=MarketInfo(Symbol(),MODE_LOTSTEP);
   lots=MathFloor(lots/lotStp)*lotStp;
   if(lots<minL)
      lots=0;
   if(lots>maxL)
      lots=maxL;
   return(NormalizeDouble(lots,2));
  }
//+------------------------------------------------------------------+
//| Get Risk Percent                                                 |
//+------------------------------------------------------------------+
double GetRiskPercent(int entryNum)
  {
   switch(InpSizingMode)
     {
      case PercentRiskEqual:
         return(InpRisk_Entry1);
      case PercentRiskCompounding:
         if(UseUnifiedTurtleSeriesRisk)
           { if(InpUnifiedTurtleSeriesRiskPercent<=0)return 0.0; return(InpUnifiedTurtleSeriesRiskPercent/3.0); }
         else
           {
            if(entryNum==1)
               return(InpRisk_Entry1);
            if(entryNum==2)
               return(InpRisk_Entry2);
            if(entryNum==3)
               return(InpRisk_Entry3);
            Print(__LINE__, ", Warning: GetRiskPercent with unexpected entryNum ",entryNum);
            return(InpRisk_Entry1);
           }
         break;
      default:
         return(0.0);
     }
   return(0.0);
  }
//+------------------------------------------------------------------+
//| Count Open Trades in Series                                      |
//+------------------------------------------------------------------+
int CountTradesInSeries()
  {
   int c=0;
   if(ticketEntry1!=0&&OrderSelect(ticketEntry1,SELECT_BY_TICKET)&&OrderCloseTime()==0&&OrderMagicNumber()==EA_MagicNumber&&OrderSymbol()==Symbol())
      c++;
   if(ticketEntry2!=0&&OrderSelect(ticketEntry2,SELECT_BY_TICKET)&&OrderCloseTime()==0&&OrderMagicNumber()==EA_MagicNumber&&OrderSymbol()==Symbol())
      c++;
   if(ticketEntry3!=0&&OrderSelect(ticketEntry3,SELECT_BY_TICKET)&&OrderCloseTime()==0&&OrderMagicNumber()==EA_MagicNumber&&OrderSymbol()==Symbol())
      c++;
   return(c);
  }
//+------------------------------------------------------------------+
//| Get Average Entry Price                                          |
//+------------------------------------------------------------------+
double GetAverageEntryPrice()
  {
   double totL=0,wPSum=0;
   int oC=0;
   if(ticketEntry1!=0&&OrderSelect(ticketEntry1,SELECT_BY_TICKET)&&OrderCloseTime()==0&&OrderMagicNumber()==EA_MagicNumber)
     {
      totL+=OrderLots();
      wPSum+=OrderOpenPrice()*OrderLots();
      oC++;
     }
   if(ticketEntry2!=0&&OrderSelect(ticketEntry2,SELECT_BY_TICKET)&&OrderCloseTime()==0&&OrderMagicNumber()==EA_MagicNumber)
     {
      totL+=OrderLots();
      wPSum+=OrderOpenPrice()*OrderLots();
      oC++;
     }
   if(ticketEntry3!=0&&OrderSelect(ticketEntry3,SELECT_BY_TICKET)&&OrderCloseTime()==0&&OrderMagicNumber()==EA_MagicNumber)
     {
      totL+=OrderLots();
      wPSum+=OrderOpenPrice()*OrderLots();
      oC++;
     }
   if(totL==0||oC==0)
      return 0.0;
   return NormalizeDouble(wPSum/totL,Digits);
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   EA_MagicNumber = GenerateMagicNumber(InpBaseMagicNumber);
   VSL_LineName_Base += IntegerToString(EA_MagicNumber);
   VTP_LineName_Base += IntegerToString(EA_MagicNumber);

   if(Digits == 3 || Digits == 5)
      pipValueInPoints = Point * 10;
   else
      pipValueInPoints = Point;
   slippagePoints = InpSlippage;

   g_brokerGmtOffset = CalculateGMTOffset();
   g_effectiveMaxSpread = MaxAllowedSpreadPoints;
   if(MaxAllowedSpreadPoints < 0)
      g_effectiveMaxSpread = 0.0;

   g_effectiveTradingEndHour = TradingEndHour;
   if(TradingEndHour < 0 || TradingEndHour > 23 || TradingStartHour < 0 || TradingStartHour > 23 || TradingStartMinute < 0 || TradingStartMinute > 59)
     {
      Print(__LINE__, ", Warning: Invalid Trading Hour/Minute inputs. StartH:", TradingStartHour, " StartM:",TradingStartMinute, " EndH:",TradingEndHour,". Using defaults.");
      if(TradingEndHour < 0 || TradingEndHour > 23)
         g_effectiveTradingEndHour = 23;
     }

   Print(__LINE__, ", EA Initialized: ", InpComment, " BaseMagic: ", InpBaseMagicNumber, " Generated EA_MagicNumber: ", EA_MagicNumber);
   Print(__LINE__, ", Virtual SL/TP System ", (UseVirtualSLTP ? "Enabled" : "Disabled"));
   if(UseVirtualSLTP)
      Print(__LINE__, ", VSL Broker SL Buffer: ", InpVslBrokerSlBufferPips, " pips. VTP Broker TP Buffer: ", InpVtpBrokerTpBufferPips, " pips.");

   string riskModeStr = "";
   if(InpSizingMode == FixedLot)
      riskModeStr = "Fixed Lot";
   else
      if(InpSizingMode == PercentRiskEqual)
        {
         riskModeStr = "Percent Risk Equal (Compounding per part)";
         Print(__LINE__, ", INFO: Compounding risk mode selected. Note: Compounding may underperform non-compounding methods if the strategy's win rate is close to its break-even point.");
        }
      else
         if(InpSizingMode == PercentRiskCompounding)
           {
            if(UseUnifiedTurtleSeriesRisk)
               riskModeStr = "Percent Risk Compounding (Unified Turtle Series Risk: " + DoubleToString(InpUnifiedTurtleSeriesRiskPercent,2) + "% total / 3 per part)";
            else
               riskModeStr = "Percent Risk Compounding (Staged Individual Risks: E1=" + DoubleToString(InpRisk_Entry1,2) + "%, E2=" + DoubleToString(InpRisk_Entry2,2) + "%, E3=" + DoubleToString(InpRisk_Entry3,2) + "%)";
            Print(__LINE__, ", INFO: Compounding risk mode selected. Note: Compounding may underperform non-compounding methods if the strategy's win rate is close to its break-even point.");
            Print(__LINE__, ", Compounding Sub-Mode: ", (UseUnifiedTurtleSeriesRisk ? "Unified Turtle Series Risk" : "Staged Individual Risks"));
           }
   Print(__LINE__, ", Risk Sizing Mode: ", riskModeStr);
   Print(__LINE__, ", Trading Hours Filter ", (EnableTradingHoursFilter ? "Enabled" : "Disabled"), " from ", TradingStartHour, ":", StringFormat("%02d", TradingStartMinute), " to ", g_effectiveTradingEndHour, ":59 Broker Time");

   ResetSeriesState();
   MonitorSpread();
   UpdateHUD();
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   DeleteLine(currentVSLLineName);
   DeleteLine(currentVTPLineName);
   Print(__LINE__, ", EA Deinitialized. Reason: ", reason);
   Print(__LINE__, ", ========== FINAL STATISTICS (Magic: ", EA_MagicNumber, ", Symbol: ", Symbol(), ") ==========");
   double winRate = 0;
   int cD = g_winningTrades+g_losingTrades;
   if(cD > 0)
      winRate = NormalizeDouble((double)g_winningTrades/cD*100.0,1);
   Print(__LINE__, ", Total Trades (OrderSend success): ", g_totalTrades);
   Print(__LINE__, ", Wins: ", g_winningTrades, " | Losses: ", g_losingTrades, " | Win Rate (W/(W+L)): ", DoubleToString(winRate,1), "%");
   Print(__LINE__, ", Total P/L Pips: ", DoubleToString(g_totalProfitLossPips,1));
   Print(__LINE__, ", Total P/L Currency: ", DoubleToString(g_totalProfitLossCurrency,2));
   if(g_spreadTickCount>0&&g_totalSpreadPoints>0)
      g_averageSpreadPoints=NormalizeDouble(g_totalSpreadPoints/g_spreadTickCount,1);
   else
      if(g_spreadTickCount>0)
         g_averageSpreadPoints=0;
   Print(__LINE__, ", Average Spread (Lifetime): ",DoubleToString(g_averageSpreadPoints,1)," points");
   Print(__LINE__, ", =================================================================");
   Comment("");
   ChartRedraw();
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   MonitorSpread();
   static datetime lastBarTime = 0;
   if(lastBarTime == Time[0] && Period() != 0)
      return;
   lastBarTime = Time[0];

   if(g_currentSpreadPoints < 0 || (g_currentSpreadPoints > g_effectiveMaxSpread && g_effectiveMaxSpread > 0))
     { UpdateHUD(); return; }
   if(!IsTradingHoursAllowed())
     { if(isSeriesActive) ManageActiveSeries(); UpdateHUD(); return; }

   if(!isSeriesActive)
      CheckForInitialEntry();
   else
      ManageActiveSeries();

   SlowDownStrategyTester();
   UpdateHUD();
  }

//+------------------------------------------------------------------+
//| Is Trading Hour Allowed                                          |
//+------------------------------------------------------------------+
bool IsTradingHoursAllowed()
  {
   if(!EnableTradingHoursFilter)
      return(true);
   datetime sTime = TimeCurrent();
   int cHour=TimeHour(sTime),cMin=TimeMinute(sTime),cDow=TimeDayOfWeek(sTime);
   bool dayOk=false;
   switch(cDow)
     {
      case 0:
         dayOk=AllowSundayTrading;
         break;
      case 1:
         dayOk=AllowMondayTrading;
         break;
      case 2:
         dayOk=AllowTuesdayTrading;
         break;
      case 3:
         dayOk=AllowWednesdayTrading;
         break;
      case 4:
         dayOk=AllowThursdayTrading;
         break;
      case 5:
         dayOk=AllowFridayTrading;
         break;
      case 6:
         dayOk=AllowSaturdayTrading;
         break;
     }
   if(!dayOk)
      return(false);
   if(cHour==DAILY_CLOSE_HOUR&&cMin>=DAILY_CLOSE_MINUTE)
      return(false);
   int cVal=cHour*100+cMin,sVal=TradingStartHour*100+TradingStartMinute,eVal=g_effectiveTradingEndHour*100+59;
   bool timeOk=(sVal<=eVal)?(cVal>=sVal&&cVal<=eVal):(cVal>=sVal||cVal<=eVal);
   if(timeOk&&(cHour==DAILY_CLOSE_HOUR&&cMin>=DAILY_CLOSE_MINUTE))
      timeOk=false;
   return(timeOk);
  }
//+------------------------------------------------------------------+
//| Slow Down Strategy Tester                                        |
//+------------------------------------------------------------------+
void SlowDownStrategyTester()
  {
   if(IsVisualMode()&&!IsOptimization())
     {
      int i=0;
      if(CountTradesInSeries()>0)
        {
         if(InTradeVisualSpeed>0)
            for(i=InTradeVisualSpeed; i>0; i--)
               ;
        }
      else
        {
         if(OutOfTradeTesterThrottleSpeed>0)
            for(i=OutOfTradeTesterThrottleSpeed; i>0; i--)
               ;
        }
     }
  }
//+------------------------------------------------------------------+
//| Heads Up Display                                                 |
//+------------------------------------------------------------------+
void UpdateHUD()
  {
   string hud=StringFormat("%s - %s [%s] (Magic: %d)\n",EANameHUD,Symbol(),PeriodIntegerToString(Period()),EA_MagicNumber);
   hud+="--------------------------------------------------\n";
   string sLo="N/A";
   if(g_spreadTickCount>0&&g_lowestSpreadPoints>=0&&g_lowestSpreadPoints<999999.0)
      sLo=DoubleToString(g_lowestSpreadPoints,1);
   hud+=StringFormat("Spread (Pts): Cur=%.1f|Avg=%.1f|Hi=%.1f|Lo=%s\n",g_currentSpreadPoints,g_averageSpreadPoints,g_highestSpreadPoints,sLo);
   hud+="Series Active: "+(isSeriesActive?"YES":"NO")+" | Entries: "+IntegerToString(entriesInSeries)+"/3\n";
   if(isSeriesActive)
     {
      hud+="Direction: "+(seriesDirection==OP_BUY?"BUY":(seriesDirection==OP_SELL?"SELL":"N/A"));
      if(UseVirtualSLTP)
         hud+=" | VSL: "+DoubleToString(virtualStopLossLevel_Series,Digits)+"\n";
      else
         hud+=" | SL: "+DoubleToString(commonStopLoss,Digits)+"\n";
     }
   else
     {
      hud+="Direction: N/A | "+(UseVirtualSLTP?"VSL":"SL")+": N/A\n";
     }
   if(UseVirtualSLTP && isSeriesActive && virtualTakeProfitLevel_Basket > 0)
      hud+="Basket VTP: " + DoubleToString(virtualTakeProfitLevel_Basket, Digits) + "\n";
   else
      if(UseVirtualSLTP && isSeriesActive)
         hud+="Basket VTP: N/A (or 0)\n";
   hud+="Trend EMA("+IntegerToString(InpTrendEMAPeriod)+" on "+PeriodIntegerToString(InpTrendEMATF)+"): Val(0) "+DoubleToString(iMA(Symbol(),InpTrendEMATF,InpTrendEMAPeriod,0,MODE_EMA,PRICE_CLOSE,0),Digits)+"\n";
   hud+="EA Status: "+GetEntryReadinessStatus()+"\n";
   hud+="Trading Hours: "+GetTradingHoursStatus()+"\n";
   string tInfo="Trade: NONE\n";
   if(isSeriesActive&&entriesInSeries>0)
     {
      double avgE=GetAverageEntryPrice(),totL=0,pnlC=0,pnlP=0;
      int oC=0;
      int tks[3];
      tks[0]=ticketEntry1;
      tks[1]=ticketEntry2;
      tks[2]=ticketEntry3;
      for(int i=0; i<3; i++)
        {
         if(tks[i]>0&&OrderSelect(tks[i],SELECT_BY_TICKET,MODE_TRADES))
           {
            if(OrderCloseTime()==0&&OrderMagicNumber()==EA_MagicNumber)
              {
               totL+=OrderLots();
               pnlC+=OrderProfit()+OrderSwap()+OrderCommission();
               if(pipValueInPoints>0)
                 {
                  if(OrderType()==OP_BUY)
                     pnlP+=(Bid-OrderOpenPrice())/pipValueInPoints;
                  else
                     pnlP+=(OrderOpenPrice()-Ask)/pipValueInPoints;
                 }
               oC++;
              }
           }
        }
      if(oC>0)
        {
         tInfo=StringFormat("Avg Entry: %.*f|Tot Lots: %.2f|Open: %d\n",Digits,avgE,totL,oC);
         tInfo+=StringFormat("Live P/L $: %.2f (%.1f pips)\n",pnlC,pnlP);
        }
      else
         if(entriesInSeries>0)
            tInfo="Trade: Series active, no open positions matched EA.\n";
     }
   hud+=tInfo;
   hud+="-------------------- STATS ---------------------\n";
   double wR=0;
   int cD=g_winningTrades+g_losingTrades;
   if(cD>0)
      wR=NormalizeDouble((double)g_winningTrades/cD*100.0,1);
   hud+=StringFormat("Total Trades: %d | Wins: %d | Losses: %d\n",g_totalTrades,g_winningTrades,g_losingTrades);
   hud+=StringFormat("Win Rate (W/L): %.1f %% \n",wR);
   hud+=StringFormat("Total P/L (Pips): %.1f | Total P/L ($): %.2f\n",g_totalProfitLossPips,g_totalProfitLossCurrency);
   hud+="--------------------------------------------------";
   Comment(hud);
  }
//+------------------------------------------------------------------+
string GetActiveLinesInfo(ENUM_TIMEFRAMES tf)
  {
   if(tf==(ENUM_TIMEFRAMES)InpTrendEMATF)
     {
      double eV=iMA(Symbol(),InpTrendEMATF,InpTrendEMAPeriod,0,MODE_EMA,PRICE_CLOSE,0);
      if(eV==0&&IsTesting())
         eV=iMA(Symbol(),InpTrendEMATF,InpTrendEMAPeriod,0,MODE_EMA,PRICE_CLOSE,1);
      return "TrendEMA("+IntegerToString(InpTrendEMAPeriod)+"): "+DoubleToString(eV,Digits);
     }
   if(tf==(ENUM_TIMEFRAMES)Period())
     {
      return StringFormat("MACD(0):M:%.*f S:%.*f",Digits,iMACD(NULL,0,InpMACDFast,InpMACDSlow,InpMACDSignal,PRICE_CLOSE,MODE_MAIN,0),Digits,iMACD(NULL,0,InpMACDFast,InpMACDSlow,InpMACDSignal,PRICE_CLOSE,MODE_SIGNAL,0));
     }
   return "";
  }
//+------------------------------------------------------------------+
string GetStateString(int state_unused)
  {
   if(isSeriesActive)
     {
      if(seriesDirection==OP_BUY)
         return"SERIES_BUY";
      if(seriesDirection==OP_SELL)
         return"SERIES_SELL";
      return"SERIES_UNK";
     }
   RefreshRates();
   double tEMA=iMA(Symbol(),InpTrendEMATF,InpTrendEMAPeriod,0,MODE_EMA,PRICE_CLOSE,0);
   if(tEMA==0&&IsTesting())
      tEMA=iMA(Symbol(),InpTrendEMATF,InpTrendEMAPeriod,0,MODE_EMA,PRICE_CLOSE,1);
   if(Close[0]>tEMA&&tEMA!=0)
      return"Price>TrendEMA";
   if(Close[0]<tEMA&&tEMA!=0)
      return"Price<TrendEMA";
   return"NEUTRAL/INIT";
  }
//+------------------------------------------------------------------+
string GetEntryReadinessStatus()
  {
   if(isSeriesActive)
      return"Series Active("+IntegerToString(entriesInSeries)+"/3)";
   if(!IsTradingHoursAllowed())
      return"Trading Hours Inactive";
   if(g_currentSpreadPoints<0||(g_currentSpreadPoints>g_effectiveMaxSpread&&g_effectiveMaxSpread>0))
      return"Waiting(Spread:"+DoubleToString(g_currentSpreadPoints,1)+"/"+DoubleToString(g_effectiveMaxSpread,1)+")";
   return"Monitoring Initial Entry";
  }
//+------------------------------------------------------------------+
string GetOrderTypeString(int tkt)
  {
   if(tkt>0)
     {
      if(OrderSelect(tkt,SELECT_BY_TICKET,MODE_TRADES))
        {
         int typ=OrderType();
         if(typ==OP_BUY)
            return"BUY";
         if(typ==OP_SELL)
            return"SELL";
         return"Unk("+IntegerToString(typ)+")";
        }
      else
        {
         return"N/A(SelFail)";
        }
     }
   return"N/A";
  }
//+------------------------------------------------------------------+
string GetTradingHoursStatus()
  {
   if(!EnableTradingHoursFilter)
      return"Active(Filter Off)";
   string sTS=StringFormat("%02d:%02d",TradingStartHour,TradingStartMinute);
   string eTS=StringFormat("%02d:59",g_effectiveTradingEndHour);
   string dCS=StringFormat("(DailyStop %02d:%02d)",DAILY_CLOSE_HOUR,DAILY_CLOSE_MINUTE);
   if(IsTradingHoursAllowed())
      return StringFormat("Active[%s-%s]%s",sTS,eTS,dCS);
   else
     {
      datetime sT=TimeCurrent();
      string cTS=StringFormat("%02d:%02d",TimeHour(sT),TimeMinute(sT));
      return StringFormat("Inactive(Now:%s)[%s-%s]%s",cTS,sTS,eTS,dCS);
     }
  }
//+------------------------------------------------------------------+
//| Log Stats for a closed trade                                     |
//+------------------------------------------------------------------+
void LogClosedTradeStats(int cTkt)
  {
   if(OrderSelect(cTkt, SELECT_BY_TICKET, MODE_HISTORY))
     {
      if(OrderMagicNumber() == EA_MagicNumber && OrderSymbol() == Symbol() && OrderCloseTime() > seriesStartTime)
        {
         double pnl=OrderProfit(),comm=OrderCommission(),swap=OrderSwap(),totPnl=pnl+comm+swap,pips=0;
         if(pipValueInPoints>0)
           {
            if(OrderType()==OP_BUY)
               pips=(OrderClosePrice()-OrderOpenPrice())/pipValueInPoints;
            else
               pips=(OrderOpenPrice()-OrderClosePrice())/pipValueInPoints;
           }
         pips=NormalizeDouble(pips,1);
         g_totalProfitLossCurrency+=totPnl;
         g_totalProfitLossPips+=pips;
         if(totPnl>0)
            g_winningTrades++;
         else
            if(totPnl<0)
               g_losingTrades++;
         Print(__LINE__, ", Logged closed Tkt:",cTkt," P/L:",DoubleToString(totPnl,2),"(",DoubleToString(pips,1),"pips). Reason: ", OrderComment());
        }
     }
  }
//+------------------------------------------------------------------+
//| Reset Series State                                               |
//+------------------------------------------------------------------+
void ResetSeriesState()
  {
   if(UseVirtualSLTP)
     {
      DeleteLine(currentVSLLineName);
      DeleteLine(currentVTPLineName);
      currentVSLLineName="";
      currentVTPLineName="";
     }
   virtualStopLossLevel_Series=0.0;
   virtualTakeProfitLevel_Basket=0.0;
   isSeriesActive=false;
   entriesInSeries=0;
   ticketEntry1=0;
   ticketEntry2=0;
   ticketEntry3=0;
   commonStopLoss=0.0;
   seriesDirection=-1;
   seriesStartTime=0;
   Print(__LINE__, ", Trade series state has been reset (including VSL/VTP if active).");
   ChartRedraw();
  }

//+------------------------------------------------------------------+
//| Helper: Set Broker SL/TP & Draw Virtual Lines after order open   |
//+------------------------------------------------------------------+
bool SetBrokerSLTP_ForOrder(int ticket, double vsl_level_for_broker_sl, double vtp_level_for_broker_tp, int orderOpenType)
  {
   if(ticket <= 0)
     {
      Print(__LINE__, ", SetBrokerSLTP: Invalid ticket: ", ticket);
      return false;
     }
   if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
     { Print(__LINE__, ", SetBrokerSLTP: Could not select order #", ticket, ". Err: ", GetLastError()); return false; }
   if(OrderMagicNumber()!=EA_MagicNumber||OrderSymbol()!=Symbol()||OrderType()!=orderOpenType)
     { Print(__LINE__, ", SetBrokerSLTP: Order #", ticket, " mismatch. Cannot modify."); return false; }

   double orderOpenPrice = OrderOpenPrice();
   double brokerSL = 0;
   double brokerTP = 0;

   if(UseVirtualSLTP)
     {
      if(vsl_level_for_broker_sl > 0)
        {
         if(orderOpenType == OP_BUY)
            brokerSL = NormalizeDouble(vsl_level_for_broker_sl - (InpVslBrokerSlBufferPips * pipValueInPoints), Digits);
         else
            brokerSL = NormalizeDouble(vsl_level_for_broker_sl + (InpVslBrokerSlBufferPips * pipValueInPoints), Digits);
        }
      if(vtp_level_for_broker_tp > 0)
        {
         if(orderOpenType == OP_BUY)
            brokerTP = NormalizeDouble(vtp_level_for_broker_tp + (InpVtpBrokerTpBufferPips * pipValueInPoints), Digits);
         else
            brokerTP = NormalizeDouble(vtp_level_for_broker_tp - (InpVtpBrokerTpBufferPips * pipValueInPoints), Digits);
        }
     }
   else
     {
      brokerSL = vsl_level_for_broker_sl;
      brokerTP = vtp_level_for_broker_tp;
     }

   double stopLevelDist = MarketInfo(Symbol(), MODE_STOPLEVEL) * Point;
   if(brokerSL != 0)
     {
      if(orderOpenType == OP_BUY && (orderOpenPrice - brokerSL < stopLevelDist - Point*0.000001)) // Changed epsilon
        { Print(__LINE__, ", BrokerSL BUY #",ticket," (Attempted:",DoubleToString(brokerSL,Digits),") too close. Adjusting."); brokerSL = NormalizeDouble(orderOpenPrice - (stopLevelDist + pipValueInPoints), Digits); }
      else
         if(orderOpenType == OP_SELL && (brokerSL - orderOpenPrice < stopLevelDist - Point*0.000001)) // Changed epsilon
           { Print(__LINE__, ", BrokerSL SELL #",ticket," (Attempted:",DoubleToString(brokerSL,Digits),") too close. Adjusting."); brokerSL = NormalizeDouble(orderOpenPrice + (stopLevelDist + pipValueInPoints), Digits); }
     }
   if(brokerTP != 0)
     {
      if(orderOpenType == OP_BUY && (brokerTP - orderOpenPrice < stopLevelDist - Point*0.000001)) // Changed epsilon
        { Print(__LINE__, ", BrokerTP BUY #",ticket," (Attempted:",DoubleToString(brokerTP,Digits),") too close. Setting TP 0."); brokerTP = 0.0; }
      else
         if(orderOpenType == OP_SELL && (orderOpenPrice - brokerTP < stopLevelDist - Point*0.000001)) // Changed epsilon
           { Print(__LINE__, ", BrokerTP SELL #",ticket," (Attempted:",DoubleToString(brokerTP,Digits),") too close. Setting TP 0."); brokerTP = 0.0; }
     }

   RefreshRates();
   if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES)) // Re-select before Modify
     { Print(__LINE__, ", SetBrokerSLTP: Re-Select FAILED for order #", ticket, " before modify. Error: ", GetLastError()); return false; }
   bool modified = OrderModify(ticket, OrderOpenPrice(), brokerSL, brokerTP, 0, clrNONE);

   if(modified)
     {
      Print(__LINE__, ", SetBrokerSLTP_ForOrder: OrderModify call for #", ticket, " was successful. Attempted Broker SL: ", DoubleToString(brokerSL, Digits), ", Attempted Broker TP: ", DoubleToString(brokerTP, Digits));
      return true;
     }
   else
     {
      Print(__LINE__, ", SetBrokerSLTP_ForOrder: OrderModify call for #", ticket, " FAILED. Error: ", GetLastError(), ". Attempted SL:", DoubleToString(brokerSL, Digits), " TP:", DoubleToString(brokerTP, Digits));
      return false;
     }
  }

//+------------------------------------------------------------------+
//| Check for Initial Entry                                          |
//+------------------------------------------------------------------+
void CheckForInitialEntry()
  {
   if(isSeriesActive || CountTradesInSeries() > 0)
      return;
   double mMain1=iMACD(NULL,0,InpMACDFast,InpMACDSlow,InpMACDSignal,PRICE_CLOSE,MODE_MAIN,1), mSig1=iMACD(NULL,0,InpMACDFast,InpMACDSlow,InpMACDSignal,PRICE_CLOSE,MODE_SIGNAL,1);
   double mMain2=iMACD(NULL,0,InpMACDFast,InpMACDSlow,InpMACDSignal,PRICE_CLOSE,MODE_MAIN,2), mSig2=iMACD(NULL,0,InpMACDFast,InpMACDSlow,InpMACDSignal,PRICE_CLOSE,MODE_SIGNAL,2);
   double cTrendEMA=iMA(Symbol(),InpTrendEMATF,InpTrendEMAPeriod,0,MODE_EMA,PRICE_CLOSE,iBarShift(Symbol(),InpTrendEMATF,Time[1]));
   if(cTrendEMA==0)
      return;
   bool lSig=false,sSig=false;
   double VSL_pot=0;
   if(Close[1]>cTrendEMA&&mMain1>mSig1&&mMain2<mSig2&&mMain1<0)
     {
      lSig=true;
      VSL_pot=NormalizeDouble(cTrendEMA-InpStopLossBufferPips*pipValueInPoints,Digits);
     }
   else
      if(Close[1]<cTrendEMA&&mMain1<mSig1&&mMain2>mSig2&&mMain1>0)
        {
         sSig=true;
         VSL_pot=NormalizeDouble(cTrendEMA+InpStopLossBufferPips*pipValueInPoints,Digits);
        }

   if(lSig||sSig)
     {
      int potDir=(lSig?OP_BUY:OP_SELL);
      double rPcnt=GetRiskPercent(1),lots=CalculateLotSize(VSL_pot,potDir,rPcnt);
      if(lots>0)
        {
         RefreshRates();
         double eP=(potDir==OP_BUY)?Ask:Bid;
         string cmt=StringFormat("%s E1 %s",InpComment,(potDir==OP_BUY?"B":"S"));
         g_lastOrderSendTime=TimeCurrent();
         g_lastOrderSelectDurationMs=0;
         int tkt=OrderSend(Symbol(),potDir,lots,eP,slippagePoints,0,0,cmt,EA_MagicNumber,0,(potDir==OP_BUY?clrBlue:clrRed));
         if(tkt>0)
           {
            datetime sST=TimeCurrent();
            bool sel=false;
            for(int k=0; k<50; k++)
              {
               RefreshRates();
               if(OrderSelect(tkt,SELECT_BY_TICKET,MODE_TRADES))
                 {
                  sel=true;
                  break;
                 }
               Sleep(100);
              }
            g_lastOrderSelectDurationMs=(ulong)((TimeCurrent()-sST)*1000.0);
            if(sel)
              {
               seriesDirection=potDir;
               commonStopLoss=VSL_pot;
               virtualStopLossLevel_Series=commonStopLoss;
               double oP=OrderOpenPrice();
               virtualTakeProfitLevel_Basket=CalculateTakeProfit(oP,virtualStopLossLevel_Series,seriesDirection,InpRR_Entry1_2);
               SetBrokerSLTP_ForOrder(tkt,virtualStopLossLevel_Series,virtualTakeProfitLevel_Basket,seriesDirection);
               if(UseVirtualSLTP)
                 {
                  currentVSLLineName=VSL_LineName_Base+IntegerToString(tkt);
                  DrawUpdateLine(currentVSLLineName,virtualStopLossLevel_Series,InpVSLLineColor,InpVSLTPLineStyle,InpVSLTPLineWidth);
                  currentVTPLineName=VTP_LineName_Base+IntegerToString(tkt);
                  if(virtualTakeProfitLevel_Basket>0)
                     DrawUpdateLine(currentVTPLineName,virtualTakeProfitLevel_Basket,InpVTPLineColor,InpVSLTPLineStyle,InpVSLTPLineWidth);
                 }
               ticketEntry1=tkt;
               isSeriesActive=true;
               entriesInSeries=1;
               seriesStartTime=TimeCurrent();
               g_totalTrades++;
               Print(__LINE__, ", Initial Entry #",ticketEntry1," L:",DoubleToString(OrderLots(),2)," OP:",DoubleToString(oP,Digits),(UseVirtualSLTP?" VSL:":" SL:"),DoubleToString(commonStopLoss,Digits),(UseVirtualSLTP?" InitVTP:":" TP:"),DoubleToString((UseVirtualSLTP?virtualTakeProfitLevel_Basket:OrderTakeProfit()),Digits));
              }
            else
              {
               Print(__LINE__, ", OrderSend OK Initial (Tkt ",tkt,") but Select FAIL. Closing.");
               RefreshRates();
               double cP=(potDir==OP_BUY)?Bid:Ask;
               bool cl=OrderClose(tkt,lots,cP,slippagePoints,clrRed);
               if(cl)
                  Print(__LINE__, ", Closed naked #",tkt);
               else
                  Print(__LINE__, ", FAIL Close naked #",tkt,": ",GetLastError());
              }
           }
         else
            Print(__LINE__, ", OrderSend Error Initial (Naked Send): ",GetLastError());
        }
     }
  }

//+------------------------------------------------------------------+
//| Close All Open Orders in the Current Series at Market            |
//+------------------------------------------------------------------+
bool CloseSeriesAtMarket(string reason)
  {
   if(!isSeriesActive)
      return false;
   Print(__LINE__, ", CloseSeriesAtMarket: ", reason, ". Closing series Magic: ", EA_MagicNumber);
   bool allClosedSuccessfully = true;
   int ticketsToClose[3] = {0,0,0};
   int ordersFound = 0;
   if(ticketEntry1!=0 && OrderSelect(ticketEntry1,SELECT_BY_TICKET,MODE_TRADES) && OrderCloseTime()==0)
      ticketsToClose[ordersFound++]=ticketEntry1;
   if(ticketEntry2!=0 && OrderSelect(ticketEntry2,SELECT_BY_TICKET,MODE_TRADES) && OrderCloseTime()==0)
      ticketsToClose[ordersFound++]=ticketEntry2;
   if(ticketEntry3!=0 && OrderSelect(ticketEntry3,SELECT_BY_TICKET,MODE_TRADES) && OrderCloseTime()==0)
      ticketsToClose[ordersFound++]=ticketEntry3;

   if(ordersFound == 0)
     {
      Print(__LINE__, ", CloseSeriesAtMarket: No open orders found for active series.");
      ResetSeriesState();
      return true;
     }

   for(int i=0; i<ordersFound; i++)
     {
      int cTkt = ticketsToClose[i];
      if(OrderSelect(cTkt,SELECT_BY_TICKET,MODE_TRADES))
        {
         double lots=OrderLots();
         int type=OrderType();
         double price=0;
         RefreshRates();
         if(type==OP_BUY)
            price=Bid;
         else
            if(type==OP_SELL)
               price=Ask;
            else
               continue;
         if(price<=0)
           {
            Print(__LINE__, ", CloseSeriesAtMarket: Invalid MktPrice #",cTkt);
            allClosedSuccessfully=false;
            continue;
           }
         double pnl=OrderProfit(),comm=OrderCommission(),swap=OrderSwap(),totPnl=pnl+comm+swap,pips=0;
         if(pipValueInPoints>0)
           {
            if(type==OP_BUY)
               pips=(price-OrderOpenPrice())/pipValueInPoints;
            else
               pips=(OrderOpenPrice()-price)/pipValueInPoints;
           }
         pips=NormalizeDouble(pips,1);
         g_totalProfitLossCurrency+=totPnl;
         g_totalProfitLossPips+=pips;
         if(totPnl>0)
            g_winningTrades++;
         else
            if(totPnl<0)
               g_losingTrades++;
         Print(__LINE__, ", Attempt MktClose #",cTkt," (",DoubleToString(lots,2)," ",(type==OP_BUY?"BUY":"SELL"),") at ~",DoubleToString(price,Digits),". Rsn:",reason,". P/L:",DoubleToString(totPnl,2),"(",DoubleToString(pips,1),"pips)");
         bool closed=OrderClose(cTkt,lots,price,slippagePoints,(type==OP_BUY?clrDarkOrange:clrDarkTurquoise));
         if(closed)
           {
            Print(__LINE__, ", Order #",cTkt," MktClosed by EA.");
            if(cTkt==ticketEntry1)
               ticketEntry1=0;
            else
               if(cTkt==ticketEntry2)
                  ticketEntry2=0;
               else
                  if(cTkt==ticketEntry3)
                     ticketEntry3=0;
           }
         else
           {
            Print(__LINE__, ", FAIL MktClose #",cTkt,". Err:",GetLastError());
            allClosedSuccessfully=false;
           }
        }
     }
   if(CountTradesInSeries()==0)
     {
      Print(__LINE__, ", All orders in series confirmed MktClosed by EA. Rsn:",reason);
      ResetSeriesState();
      return true;
     }
   else
      Print(__LINE__, ", Not all orders in series MktClosed. Open: ",CountTradesInSeries());
// If not all closed, don't reset series yet, VSL/VTP might trigger again or broker SL/TP might hit
// Return allClosedSuccessfully to indicate if the operation for *this call* fully succeeded.
// ManageActiveSeries will decide if it needs to return based on ManageVirtualExits.
   return allClosedSuccessfully;
  }
//+------------------------------------------------------------------+
//| Manage Virtual Exits (VSL/VTP)                                   |
//+------------------------------------------------------------------+
bool ManageVirtualExits()
  {
   if(!isSeriesActive||!UseVirtualSLTP||entriesInSeries==0||virtualStopLossLevel_Series<=0)
      return false;
   RefreshRates();
   double cBid=Bid,cAsk=Ask;
   bool exitTrig=false;
   if(seriesDirection==OP_BUY&&cBid<=virtualStopLossLevel_Series)
     {Print(__LINE__, ", VSL HIT BUY! Bid:",DoubleToString(cBid,Digits),"<=VSL:",DoubleToString(virtualStopLossLevel_Series,Digits)); exitTrig=true; if(CloseSeriesAtMarket("VSL Hit(BUY)"))return true;}
   else
      if(seriesDirection==OP_SELL&&cAsk>=virtualStopLossLevel_Series)
        {Print(__LINE__, ", VSL HIT SELL! Ask:",DoubleToString(cAsk,Digits),">=VSL:",DoubleToString(virtualStopLossLevel_Series,Digits)); exitTrig=true; if(CloseSeriesAtMarket("VSL Hit(SELL)"))return true;}
   if(!exitTrig&&virtualTakeProfitLevel_Basket>0)
     {
      if(seriesDirection==OP_BUY&&cAsk>=virtualTakeProfitLevel_Basket)
        {Print(__LINE__, ", VTP HIT BUY! Ask:",DoubleToString(cAsk,Digits),">=VTP:",DoubleToString(virtualTakeProfitLevel_Basket,Digits)); exitTrig=true; if(CloseSeriesAtMarket("VTP Hit(BUY)"))return true;}
      else
         if(seriesDirection==OP_SELL&&cBid<=virtualTakeProfitLevel_Basket)
           {Print(__LINE__, ", VTP HIT SELL! Bid:",DoubleToString(cBid,Digits),"<=VTP:",DoubleToString(virtualTakeProfitLevel_Basket,Digits)); exitTrig=true; if(CloseSeriesAtMarket("VTP Hit(SELL)"))return true;}
     }
   return exitTrig;
  }
//+------------------------------------------------------------------+
//| Check Series SL/TP (Broker side or manual close)                 |
//+------------------------------------------------------------------+
bool CheckSeriesSLTP()
  {
   bool cF=false;
   if(ticketEntry1!=0&&(!OrderSelect(ticketEntry1,SELECT_BY_TICKET,MODE_TRADES)||OrderCloseTime()!=0))
     {
      if(OrderSelect(ticketEntry1,SELECT_BY_TICKET,MODE_HISTORY)&&OrderMagicNumber()==EA_MagicNumber&&OrderCloseTime()>seriesStartTime)
         LogClosedTradeStats(ticketEntry1);
      cF=true;
      ticketEntry1=0;
     }
   if(ticketEntry2!=0&&(!OrderSelect(ticketEntry2,SELECT_BY_TICKET,MODE_TRADES)||OrderCloseTime()!=0))
     {
      if(OrderSelect(ticketEntry2,SELECT_BY_TICKET,MODE_HISTORY)&&OrderMagicNumber()==EA_MagicNumber&&OrderCloseTime()>seriesStartTime)
         LogClosedTradeStats(ticketEntry2);
      cF=true;
      ticketEntry2=0;
     }
   if(ticketEntry3!=0&&(!OrderSelect(ticketEntry3,SELECT_BY_TICKET,MODE_TRADES)||OrderCloseTime()!=0))
     {
      if(OrderSelect(ticketEntry3,SELECT_BY_TICKET,MODE_HISTORY)&&OrderMagicNumber()==EA_MagicNumber&&OrderCloseTime()>seriesStartTime)
         LogClosedTradeStats(ticketEntry3);
      cF=true;
      ticketEntry3=0;
     }
   if(cF&&CountTradesInSeries()==0)
     {
      return true;
     }
   return cF;
  }
//+------------------------------------------------------------------+
//| Manage Active Series                                             |
//+------------------------------------------------------------------+
void ManageActiveSeries()
  {
   if(!isSeriesActive)
      return;
   if(CheckSeriesSLTP())
     {
      Print(__LINE__, ", ManageActiveSeries: BrokerSLTP/Manual close. Resetting.");
      ResetSeriesState();
      return;
     }
   if(UseVirtualSLTP)
     {
      if(ManageVirtualExits())
         return;
     }
   if(entriesInSeries >= 3)
      return;

   double mMain1=iMACD(NULL,0,InpMACDFast,InpMACDSlow,InpMACDSignal,PRICE_CLOSE,MODE_MAIN,1), mSig1=iMACD(NULL,0,InpMACDFast,InpMACDSlow,InpMACDSignal,PRICE_CLOSE,MODE_SIGNAL,1);
   double mMain2=iMACD(NULL,0,InpMACDFast,InpMACDSlow,InpMACDSignal,PRICE_CLOSE,MODE_MAIN,2), mSig2=iMACD(NULL,0,InpMACDFast,InpMACDSlow,InpMACDSignal,PRICE_CLOSE,MODE_SIGNAL,2);
   double cTrendEMA=iMA(Symbol(),InpTrendEMATF,InpTrendEMAPeriod,0,MODE_EMA,PRICE_CLOSE,iBarShift(Symbol(),InpTrendEMATF,Time[1]));
   if(cTrendEMA==0)
      return;
   bool addEntrySignalCandidate=false;
   RefreshRates();
   double currentPriceForEntry=(seriesDirection==OP_BUY)?Ask:Bid, previousAvgEntryPrice=GetAverageEntryPrice();
   if(previousAvgEntryPrice==0.0&&entriesInSeries>0)
     {
      Print(__LINE__, ", ManageActiveSeries: Err-PrevAvgPrice 0, Entries ",entriesInSeries);
      return;
     }
   bool priceImproved=false;
   if(entriesInSeries>0)
     {
      if(seriesDirection==OP_BUY&&currentPriceForEntry<previousAvgEntryPrice-InpMinPriceImprovePips*pipValueInPoints)
         priceImproved=true;
      if(seriesDirection==OP_SELL&&currentPriceForEntry>previousAvgEntryPrice+InpMinPriceImprovePips*pipValueInPoints)
         priceImproved=true;
      if(!priceImproved)
         return;
     }
   else
     {
      Print(__LINE__, ", ManageActiveSeries: Called with entriesInSeries=0 for adding. Logic error.");
      return;
     }

   if(seriesDirection==OP_BUY&&Close[1]>cTrendEMA&&mMain1>mSig1&&mMain2<mSig2&&mMain1<0)
      addEntrySignalCandidate=true;
   else
      if(seriesDirection==OP_SELL&&Close[1]<cTrendEMA&&mMain1<mSig1&&mMain2>mSig2&&mMain1>0)
         addEntrySignalCandidate=true;

   if(addEntrySignalCandidate)
     {
      double minStopDistPoints = MarketInfo(Symbol(), MODE_STOPLEVEL) * Point;
      if(minStopDistPoints<=0)
         minStopDistPoints=Point*5;
      bool entryTooCloseToVSL=false;
      if(seriesDirection==OP_BUY&&(currentPriceForEntry-virtualStopLossLevel_Series<minStopDistPoints*1.5))
        {Print(__LINE__, ", Add Entry: Buy entry ",DoubleToString(currentPriceForEntry,Digits)," too close to VSL ",DoubleToString(virtualStopLossLevel_Series,Digits),". Skip."); entryTooCloseToVSL=true;}
      else
         if(seriesDirection==OP_SELL&&(virtualStopLossLevel_Series-currentPriceForEntry<minStopDistPoints*1.5))
           {Print(__LINE__, ", Add Entry: Sell entry ",DoubleToString(currentPriceForEntry,Digits)," too close to VSL ",DoubleToString(virtualStopLossLevel_Series,Digits),". Skip."); entryTooCloseToVSL=true;}
      if(entryTooCloseToVSL)
         return;

      int nextEntryNumber=entriesInSeries+1;
      double rPcnt=GetRiskPercent(nextEntryNumber);
      double lots=CalculateLotSize(virtualStopLossLevel_Series,seriesDirection,rPcnt);
      if(lots>0)
        {
         string cmt=StringFormat("%s E%d %s",InpComment,nextEntryNumber,(seriesDirection==OP_BUY?"B":"S"));
         g_lastOrderSendTime=TimeCurrent();
         g_lastOrderSelectDurationMs=0;
         int newTkt=OrderSend(Symbol(),seriesDirection,lots,currentPriceForEntry,slippagePoints,0,0,cmt,EA_MagicNumber,0,(seriesDirection==OP_BUY?clrAqua:clrPink));
         if(newTkt>0)
           {
            datetime sST=TimeCurrent();
            bool sel=false;
            for(int k=0; k<50; k++)
              {
               RefreshRates();
               if(OrderSelect(newTkt,SELECT_BY_TICKET,MODE_TRADES))
                 {
                  sel=true;
                  break;
                 }
               Sleep(100);
              }
            g_lastOrderSelectDurationMs=(ulong)((TimeCurrent()-sST)*1000.0);
            if(sel)
              {
               int tempEntriesForRRCALC=entriesInSeries+1;
               double tempNewOrderOpenPrice=OrderOpenPrice();
               double tempIndividualVTP=CalculateTakeProfit(tempNewOrderOpenPrice,virtualStopLossLevel_Series,seriesDirection,(tempEntriesForRRCALC<3?InpRR_Entry1_2:InpRR_Entry3_Final));
               SetBrokerSLTP_ForOrder(newTkt,virtualStopLossLevel_Series,tempIndividualVTP,seriesDirection);
               if(nextEntryNumber==2)
                  ticketEntry2=newTkt;
               else
                  if(nextEntryNumber==3)
                     ticketEntry3=newTkt;
               entriesInSeries=nextEntryNumber;
               g_totalTrades++;
               Print(__LINE__, ", Added Entry ",entriesInSeries,". Tkt: ",newTkt," Lots: ",DoubleToString(OrderLots(),2)," Open: ",DoubleToString(tempNewOrderOpenPrice,Digits));
               UpdateBasketTakeProfit();
              }
            else
              {
               Print(__LINE__, ", OrderSend OK for Entry ",nextEntryNumber," (Tkt ",newTkt,") but Select FAIL. Closing.");
               RefreshRates();
               double closePrice=(seriesDirection==OP_BUY)?Bid:Ask;
               bool closed=OrderClose(newTkt,lots,closePrice,slippagePoints,clrRed);
               if(closed)
                  Print(__LINE__, ", Closed naked #",newTkt);
               else
                  Print(__LINE__, ", FAIL Close naked #",newTkt,": ",GetLastError());
              }
           }
         else
            Print(__LINE__, ", OrderSend Error Add Entry ",nextEntryNumber,": ",GetLastError());
        }
     }
  }

//+------------------------------------------------------------------+
//| Update Basket Take Profit (Virtual and Broker)                   |
//+------------------------------------------------------------------+
void UpdateBasketTakeProfit()
  {
   if(!isSeriesActive||entriesInSeries==0)
      return;
   double avgE=GetAverageEntryPrice();
   if(avgE==0.0&&CountTradesInSeries()>0)
     {
      Print(__LINE__, ", UpdateBasketTP: Err AvgEntry 0, Trades:",CountTradesInSeries());
      return;
     }
   if(avgE==0.0&&CountTradesInSeries()==0)
     {
      if(isSeriesActive)
         ResetSeriesState();
      return;
     }

   double rrRatioToUse=InpRR_Entry1_2;
   int curOpenTrades=CountTradesInSeries();
   if(curOpenTrades==3)
      rrRatioToUse=InpRR_Entry3_Final;
   else
      if(curOpenTrades==0)
        {
         if(isSeriesActive)
            ResetSeriesState();
         return;
        }

   virtualTakeProfitLevel_Basket=CalculateTakeProfit(avgE,virtualStopLossLevel_Series,seriesDirection,rrRatioToUse);

   if(UseVirtualSLTP)
     {
      string baseLineIDPart = "";
      if(ticketEntry1!=0 && OrderSelect(ticketEntry1, SELECT_BY_TICKET, MODE_TRADES) && OrderCloseTime()==0)
         baseLineIDPart = IntegerToString(ticketEntry1);
      else
         if(ticketEntry2!=0 && OrderSelect(ticketEntry2, SELECT_BY_TICKET, MODE_TRADES) && OrderCloseTime()==0)
            baseLineIDPart = IntegerToString(ticketEntry2);
         else
            if(ticketEntry3!=0 && OrderSelect(ticketEntry3, SELECT_BY_TICKET, MODE_TRADES) && OrderCloseTime()==0)
               baseLineIDPart = IntegerToString(ticketEntry3);
            else
               baseLineIDPart = "Series"+IntegerToString(seriesStartTime); // Fallback using seriesStartTime

      if(currentVTPLineName == "" && virtualTakeProfitLevel_Basket > 0)
         currentVTPLineName = VTP_LineName_Base + baseLineIDPart;

      if(virtualTakeProfitLevel_Basket>0)
         DrawUpdateLine(currentVTPLineName,virtualTakeProfitLevel_Basket,InpVTPLineColor,InpVSLTPLineStyle,InpVSLTPLineWidth);
      else
        {
         DeleteLine(currentVTPLineName);
         currentVTPLineName="";
        }
     }

   int tksTU[3]= {0,0,0};
   int updC=0;
   if(ticketEntry1!=0&&OrderSelect(ticketEntry1,SELECT_BY_TICKET,MODE_TRADES)&&OrderCloseTime()==0&&OrderMagicNumber()==EA_MagicNumber)
      tksTU[updC++]=ticketEntry1;
   if(ticketEntry2!=0&&OrderSelect(ticketEntry2,SELECT_BY_TICKET,MODE_TRADES)&&OrderCloseTime()==0&&OrderMagicNumber()==EA_MagicNumber)
      tksTU[updC++]=ticketEntry2;
   if(ticketEntry3!=0&&OrderSelect(ticketEntry3,SELECT_BY_TICKET,MODE_TRADES)&&OrderCloseTime()==0&&OrderMagicNumber()==EA_MagicNumber)
      tksTU[updC++]=ticketEntry3;
   if(updC==0&&isSeriesActive)
     {
      Print(__LINE__, ", UpdateBasketTP: No valid tickets to update, but series active?");
      ResetSeriesState();
      return;
     }

   for(int i=0; i<updC; i++)
     {
      int cTkt=tksTU[i];
      if(OrderSelect(cTkt,SELECT_BY_TICKET,MODE_TRADES))
        {
         double oP=OrderOpenPrice(),exSL=OrderStopLoss(),newBTP=0;
         if(virtualTakeProfitLevel_Basket>0)
           {
            if(seriesDirection==OP_BUY)
               newBTP=NormalizeDouble(virtualTakeProfitLevel_Basket+(InpVtpBrokerTpBufferPips*pipValueInPoints),Digits);
            else
               newBTP=NormalizeDouble(virtualTakeProfitLevel_Basket-(InpVtpBrokerTpBufferPips*pipValueInPoints),Digits);
           }
         double sLD=MarketInfo(Symbol(),MODE_STOPLEVEL)*Point;
         if(newBTP!=0)
           {
            if(seriesDirection==OP_BUY&&(newBTP-oP<sLD-Point*0.000001))
              {
               Print(__LINE__, ", UpdateBasketTP: NewBTP BUY #",cTkt," too close. TP 0.");
               newBTP=0.0;
              }
            else
               if(seriesDirection==OP_SELL&&(oP-newBTP<sLD-Point*0.000001))
                 {
                  Print(__LINE__, ", UpdateBasketTP: NewBTP SELL #",cTkt," too close. TP 0.");
                  newBTP=0.0;
                 }
           }
         if(NormalizeDouble(OrderTakeProfit(),Digits)!=NormalizeDouble(newBTP,Digits))
           {
            RefreshRates();
            bool mod=OrderModify(cTkt,oP,exSL,newBTP,0,clrNONE);
            if(!mod)
               Print(__LINE__, ", UpdateBasketTP: Err Mod BrokerTP #",cTkt," to ",DoubleToString(newBTP,Digits),". Err:",GetLastError());
            else
               Print(__LINE__, ", UpdateBasketTP: Mod BrokerTP #",cTkt," to ",DoubleToString(newBTP,Digits));
           }
        }
     }
   if(updC>0)
      Print(__LINE__, ", UpdateBasketTP: VTP basket now:",DoubleToString(virtualTakeProfitLevel_Basket>0?virtualTakeProfitLevel_Basket:0.0,Digits),"(AvgE:",DoubleToString(avgE,Digits)," VSL:",DoubleToString(virtualStopLossLevel_Series,Digits)," R:R ",DoubleToString(rrRatioToUse,2),")");
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
