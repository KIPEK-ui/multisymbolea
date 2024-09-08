//+------------------------------------------------------------------+
//|                                                multisymbolea.mq5 |
//|                                  Copyright 2024, App Cross  Ltd. |
//|                                       https://www.keterdidit.com |
//|                     telegram link:https://t.me/+GzUWeTLodfpjZWU0 |
// 

//+------------------------------------------------------------------+
#property copyright "Copyright 2024, AppCross. Ltd."
#property link      "https://www.keterdidit.com"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Expert Setup                                                     |
//+------------------------------------------------------------------+
//Libraries and Setup
#include  <Trade/Trade.mqh> //Include MQL trade object functions

CTrade    *Trade;           //Declaire Trade as pointer to CTrade class
input int MagicNumber = 1;  //Unique Identifier

//Multi-Symbol EA Variables
enum   MULTISYMBOL {Current, All}; 
input  MULTISYMBOL InputMultiSymbol = Current;
string AllTradableSymbols   = "XAUUSD|XAGUSD";
int    NumberOfTradeableSymbols;
string SymbolArray[];

//Expert Core Arrays
string          SymbolMetrics[];
int             TicksProcessed[];
static datetime TimeLastTickProcessed[];

//Expert Variables
string ExpertComments = "";
int    TicksReceived  =  0;
 
 // Global variables for lot size calculation
input bool UseFixedLotSize = false; // Fixed Lot Size?
input double FixedLotSize = 0.1; // Lot Size
input double riskPercentage = 0.02; // Risk Percentage
// Input to activate or deactivate partial close
input bool EnablePartialClose = true; // Partial Close
input double PartialCloseLevel = 0.2; // Partial Close Level

//Take Profit and Stop Loss
 input int TakeProfit = 3; // Take Profit
 input int StopLoss = 1; //Stop Loss
 
// RSI Variables
string  IndicatorSignal3;
int       RsiHandle[];
input int RsiPeriod = 14; // RSI Period

//Indicator 1 Variables
string    IndicatorSignal1;
int       MacdHandle[];
input int MacdFast   = 12; // MACD Fast EMa
input int MacdSlow   = 26; // MACD Slow EMa
input int MacdSignal = 9; // MACD Signal

//Indicator 2 Variables
string    IndicatorSignal2;
int       EmaHandle[];
input int EmaPeriod = 200; // EMA Period

// ATR Variables
int       AtrHandle[];
input int AtrPeriod = 14; //ATR Period

// Global variables for DeMarker
string    IndicatorSignal4;
int DeMarkerHandle[];
input int DeMarkerPeriod = 14; // DeMarker Period

// Bollinger Bands Variables
string IndicatorSignal6;
int       BollingerHandle[];
input int BollingerPeriod = 20;// Bollinger Band Period
input double BollingerDeviation = 2.0;// Bollinger Bands Deviation

//OBV Variables
string    IndicatorSignal5;
int OBVHandle[];

// Fibonacci Retracement Variables
string IndicatorSignal7;
double FibLevels[] = {0.0, 0.236, 0.382, 0.5, 0.618, 0.786, 1.0};

// Chaikin Money Flow Variables
string IndicatorSignal8;
int CMFHandle[];
input int CMFPeriod = 20; // CMF Period

// Average Directional Index Variables
string IndicatorSignal9;
int ADXHandle[];
input int ADXPeriod = 14; // ADX Period

// Stochastic Oscillator Variables
string IndicatorSignal10;
int StochasticHandle[];
input int KPeriod = 7; // %K Period
input int DPeriod = 3; // %D Period
input int Slowing = 3; // Slowing

// Williams %R Variables
string IndicatorSignal11;
int WilliamsRHandle[];
input int WilliamsRPeriod = 7; // Williams %R Period


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   //Declare magic number for all trades
   Trade = new CTrade();
   Trade.SetExpertMagicNumber(MagicNumber);  
   
   //Set up multi-symbol EA Tradable Symbols
   if(InputMultiSymbol == Current)
   {
      NumberOfTradeableSymbols = 1;
      ArrayResize(SymbolArray,NumberOfTradeableSymbols);
      SymbolArray[0] = Symbol();
      Print("EA will process ", NumberOfTradeableSymbols, " Symbol: ", SymbolArray[0]);
   } 
   else
   {
      NumberOfTradeableSymbols = StringSplit(AllTradableSymbols, '|', SymbolArray);
      ArrayResize(SymbolArray,NumberOfTradeableSymbols);
      Print("EA will process ", NumberOfTradeableSymbols, " Symbols: ", AllTradableSymbols);
   }
   
   //Resize core arrays for Multi-Symbol EA
   ResizeCoreArrays();   
   
   //Resize indicator arrays for Multi-Symbol EA
   ResizeIndicatorArrays();
   
   //Set Up Multi-Symbol Handles for Indicators
   if(!MacdHandleMultiSymbol() || !EmaHandleMultiSymbol() || !AtrHandleMultiSymbol() || !RsiHandleMultiSymbol() || !DeMarkerHandleMultiSymbol() || !OBVHandleMultiSymbol()|| !BollingerHandleMultiSymbol()|| !ADXHandleMultiSymbol() || !StochasticHandleMultiSymbol() || !WilliamsRHandleMultiSymbol())
       return(INIT_FAILED);
   
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   //Release Indicator Arrays
   ReleaseIndicatorArrays();
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    //Declare comment variables
   ExpertComments="";
   TicksReceived++;

   // Check if equity is greater than balance by 50%
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(accountEquity > accountBalance * 1.50)
   {
      // Close all positions
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         Trade.PositionClose(ticket);
      }
      Print("All positions closed as equity is greater than balance by 2%");
      return;
   }

   // Run multi-symbol loop   
   for(int SymbolLoop=0; SymbolLoop < NumberOfTradeableSymbols; SymbolLoop++)
   {
      // Store Current Symbol
      string CurrentSymbol = SymbolArray[SymbolLoop];
           // Check if trading is allowed
        if (!IsTradingAllowed(CurrentSymbol))
        {
            continue;
        }

      // Check for new candle based on opening time of bar
      bool IsNewCandle = false;   
      if(TimeLastTickProcessed[SymbolLoop] != iTime(CurrentSymbol,Period(),0))
      {
         IsNewCandle   = true;
         TimeLastTickProcessed[SymbolLoop]  = iTime(CurrentSymbol,Period(),0);      
      } 
      // Process strategy only if it is a new candle
      if(IsNewCandle == true)
      {
         TicksProcessed[SymbolLoop]++; 

         // Indicator 1 - Trigger - MACD
         IndicatorSignal1 = GetMacdSignalOpen(SymbolLoop);
         
         // Indicator 2 - Filter - EMA
         IndicatorSignal2 = GetEmaOpenSignal(SymbolLoop);
         // RSI Signal
         IndicatorSignal3 = GetRsiSignal(SymbolLoop);
         //DeMarker Signal
         IndicatorSignal4 = GetDeMarkerSignal(SymbolLoop);
         //OBV Signal
         IndicatorSignal5 = GetOBVSignal(SymbolLoop);
         //Bollinger Bands Signal
         IndicatorSignal6 = GetBollingerSignal(SymbolLoop);
            // Fibonacci Retracement Signal
         IndicatorSignal7 = GetFibonacciSignal(SymbolLoop);
         // Chaikin Money Flow Signal
         IndicatorSignal8 = GetCMFSignal(SymbolLoop);
         // ADX Signal
         IndicatorSignal9 = GetADXSignal(SymbolLoop);
         // Stochastic Oscillator Signal
         IndicatorSignal10 = GetStochasticSignal(SymbolLoop);
         // Williams %R Signal
         IndicatorSignal11 = GetWilliamsRSignal(SymbolLoop);

         // Debugging information
         Print("Symbol: ", CurrentSymbol, " |MACD: ", IndicatorSignal1, " |EMA: ", IndicatorSignal2, " |RSI Signal: ", IndicatorSignal3, " |DeM Signal: ", IndicatorSignal4 ," |OBV Signal: ", IndicatorSignal5, " |Bollinger Signal: ", IndicatorSignal6, " |Fibonacci Signal: ", IndicatorSignal7, " |CMF Signal: ", IndicatorSignal8, " |ADX Signal: ", IndicatorSignal9, " |Stochastic Signal: ", IndicatorSignal10, " |Williams %R Signal: ", IndicatorSignal11);

         // Check for existing positions
         bool hasBuyPosition = false;
         bool hasSellPosition = false;
         ulong positionTicket = 0;
         for(int i = 0; i < PositionsTotal(); i++)
         {
            if(PositionGetSymbol(i) == CurrentSymbol)
            {
               if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
                  hasBuyPosition = true;
               else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
                  hasSellPosition = true;
            }
         }
// Variables to store trade details
            double Price = 0.0;
            double TakeProfitPrice = 0.0;
            double LotSize = 0.0;
            ENUM_ORDER_TYPE OrderType = ORDER_TYPE_BUY;
         // Enter Trades based on combined signals
         if(IndicatorSignal3 == "Long" && IndicatorSignal6 == "Long" && IndicatorSignal9 == "Strong Trend" && IndicatorSignal10 == "Oversold" && IndicatorSignal11 == "Oversold"  )
         {
            if(!hasBuyPosition)
            {
               Print("Opening BUY trade for ", CurrentSymbol);
               if(hasSellPosition)
                  Trade.PositionClose(CurrentSymbol); // Close existing sell position
                    OrderType = ORDER_TYPE_BUY;
                  ProcessTradeOpen(CurrentSymbol, SymbolLoop, OrderType, Price, TakeProfitPrice, LotSize);            }
            else
            {
               Print("BUY position already open for ", CurrentSymbol);
            }
         }
         else if(IndicatorSignal3 == "Short" && IndicatorSignal6 == "Short" && IndicatorSignal9 == "Strong Trend" && IndicatorSignal10 == "Overbought" && IndicatorSignal11 == "Overbought")
         {
            if(!hasSellPosition)
            {
               Print("Opening SELL trade for ", CurrentSymbol);
               if(hasBuyPosition)
                  Trade.PositionClose(CurrentSymbol); // Close existing buy position
                    OrderType = ORDER_TYPE_SELL;
                  ProcessTradeOpen(CurrentSymbol, SymbolLoop, OrderType, Price, TakeProfitPrice, LotSize);            }
            else
            {
               Print("SELL position already open for ", CurrentSymbol);
            }
         }
         // Implement partial close if enabled
            if (EnablePartialClose && positionTicket != 0)
            {
                 
                double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
                double currentPrice = (OrderType == ORDER_TYPE_BUY) ? SymbolInfoDouble(CurrentSymbol, SYMBOL_BID) : SymbolInfoDouble(CurrentSymbol, SYMBOL_ASK);
                double PartialClosePrice = 0.0;

                if (OrderType == ORDER_TYPE_BUY)
                {
                    PartialClosePrice = entryPrice + (TakeProfitPrice - entryPrice) * PartialCloseLevel;
                    if (currentPrice >= PartialClosePrice)
                    {
                        double PartialLotSize = PositionGetDouble(POSITION_VOLUME) * PartialCloseLevel;
                        Trade.PositionClosePartial(positionTicket, PartialLotSize);
                        Print("Partial close executed for ", CurrentSymbol, " at price ", PartialClosePrice, " for lot size ", PartialLotSize);
                    }
                }
                else if (OrderType == ORDER_TYPE_SELL)
                {
                    PartialClosePrice = entryPrice - (entryPrice - TakeProfitPrice) * PartialCloseLevel;
                    if (currentPrice <= PartialClosePrice)
                    {
                        double PartialLotSize = PositionGetDouble(POSITION_VOLUME) * PartialCloseLevel;
                        Trade.PositionClosePartial(positionTicket, PartialLotSize);
                        Print("Partial close executed for ", CurrentSymbol, " at price ", PartialClosePrice, " for lot size ", PartialLotSize);
                    }
                }
            }
        
    
         // Update Symbol Metrics with trade decisions
                   SymbolMetrics[SymbolLoop] = CurrentSymbol + 
                            " | Ticks Processed: " + IntegerToString(TicksProcessed[SymbolLoop])+
                            " | Last Candle: " + TimeToString(TimeLastTickProcessed[SymbolLoop])+
                            " | Trade Decision: " + ((IndicatorSignal3 == "Long" && IndicatorSignal6 == "Long" && IndicatorSignal9 == "Strong Trend" && IndicatorSignal10 == "Oversold" && IndicatorSignal11 == "Oversold") ? "BUY" : 
                                                    (IndicatorSignal3 == "Short" && IndicatorSignal6 == "Short" && IndicatorSignal9 == "Strong Trend" && IndicatorSignal10 == "Overbought" && IndicatorSignal11 == "Overbought") ? "SELL" : "HOLD");

      }
      
      // Update expert comments for each symbol
      ExpertComments = ExpertComments + SymbolMetrics[SymbolLoop] + "\n\r";
   }
   
   // Comment expert behaviour
   Comment("\n\rExpert: ", MagicNumber, "\n\r",
            "MT5 Server Time: ", TimeCurrent(), "\n\r",
            "Ticks Received: ", TicksReceived,"\n\r\n\r",  
            "Symbols Traded:\n\r", 
            ExpertComments
            );

   // Update trailing stop loss and take profit
   UpdateTrailingStops();
}
//+------------------------------------------------------------------+
//| Check if trading conditions are met                              |
//+------------------------------------------------------------------+
bool IsTradingAllowed(string symbol)
{
    // Filter 1: Avoid trading during low volatility periods
    double atr = iATR(symbol, Period(), AtrPeriod);
    double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
    double atrThreshold = currentPrice * 0.003; // 0.5% of the current price
    if (atr < atrThreshold)
    {
        Print("Trading not allowed: Low volatility (ATR < threshold)");
        return false;
    }

    // Filter 2: Avoid trading during major news events
    datetime currentTime = TimeCurrent();
    if (IsMajorNewsEvent(currentTime))
    {
        Print("Trading not allowed: Major news event");
        return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| Check if current time is during a major news event               |
//+------------------------------------------------------------------+
bool IsMajorNewsEvent(datetime currentTime)
{
    // Example: Avoid trading during specific time ranges (e.g., NFP, FOMC)
    datetime nfpStartTime = D'2024.09.06 13:30:00';
    datetime nfpEndTime = D'2024.09.06 14:30:00';
    if (currentTime >= nfpStartTime && currentTime <= nfpEndTime)
    {
        return true;
    }

    // Add more news event time ranges as needed

    return false;
}



//+------------------------------------------------------------------+
//| Update trailing stop loss and take profit                        |
//+------------------------------------------------------------------+
void UpdateTrailingStops()
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      string symbol = PositionGetSymbol(i);
      double price = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_BID) : SymbolInfoDouble(symbol, SYMBOL_ASK);
      double stopLoss = PositionGetDouble(POSITION_SL);
      double takeProfit = PositionGetDouble(POSITION_TP);
      double newStopLoss, newTakeProfit;

      // Ensure the symbol is in the tradable symbols
      bool isTradableSymbol = false;
      int SymbolLoop = -1;
      for(int j = 0; j < NumberOfTradeableSymbols; j++)
      {
         if(SymbolArray[j] == symbol)
         {
            isTradableSymbol = true;
            SymbolLoop = j;
            break;
         }
      }

      if(isTradableSymbol)
      {
         double atr = GetAtrValue(SymbolLoop);

         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         {
            newStopLoss = price - atr;
            newTakeProfit = price + 3 * atr;
            if(newStopLoss > stopLoss)
            {
               Trade.PositionModify(ticket, newStopLoss, takeProfit);
               NotifyUser("Trailing Stop Loss updated for " + symbol + " to " + DoubleToString(newStopLoss, SymbolInfoInteger(symbol, SYMBOL_DIGITS)));
            }
            if(newTakeProfit > takeProfit)
            {
               Trade.PositionModify(ticket, stopLoss, newTakeProfit);
               NotifyUser("Trailing Take Profit updated for " + symbol + " to " + DoubleToString(newTakeProfit, SymbolInfoInteger(symbol, SYMBOL_DIGITS)));
            }
         }
         else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
         {
            newStopLoss = price +  atr;
            newTakeProfit = price - 3 * atr;
            if(newStopLoss < stopLoss)
            {
               Trade.PositionModify(ticket, newStopLoss, takeProfit);
               NotifyUser("Trailing Stop Loss updated for " + symbol + " to " + DoubleToString(newStopLoss, SymbolInfoInteger(symbol, SYMBOL_DIGITS)));
            }
            if(newTakeProfit < takeProfit)
            {
               Trade.PositionModify(ticket, stopLoss, newTakeProfit);
               NotifyUser("Trailing Take Profit updated for " + symbol + " to " + DoubleToString(newTakeProfit, SymbolInfoInteger(symbol, SYMBOL_DIGITS)));
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Notify user                                                      |
//+------------------------------------------------------------------+
void NotifyUser(string message)
{
   Print(message);
   // You can also use other notification methods like sending an email or push notification
}

//+------------------------------------------------------------------+
//| Expert custom function                                           |
//+------------------------------------------------------------------+
//Resize Core Arrays for multi-symbol EA
void ResizeCoreArrays()
{
   ArrayResize(SymbolMetrics,         NumberOfTradeableSymbols);
   ArrayResize(TicksProcessed,        NumberOfTradeableSymbols); 
   ArrayResize(TimeLastTickProcessed, NumberOfTradeableSymbols);
   
}

//Resize Indicator for multi-symbol EA
void ResizeIndicatorArrays()
{
   //Indicator Handle Arrays
   ArrayResize(MacdHandle, NumberOfTradeableSymbols);  
   ArrayResize(EmaHandle,  NumberOfTradeableSymbols); 
   ArrayResize(AtrHandle, NumberOfTradeableSymbols);
   ArrayResize(RsiHandle, NumberOfTradeableSymbols);
   ArrayResize(DeMarkerHandle, NumberOfTradeableSymbols);
   ArrayResize(OBVHandle, NumberOfTradeableSymbols);
   ArrayResize(BollingerHandle, NumberOfTradeableSymbols);
   ArrayResize(CMFHandle, NumberOfTradeableSymbols);
   ArrayResize(ADXHandle, NumberOfTradeableSymbols);
   ArrayResize(StochasticHandle, NumberOfTradeableSymbols);
   ArrayResize(WilliamsRHandle, NumberOfTradeableSymbols);
}

//Release indicator handles from Metatrader cache for multi-symbol EA
void ReleaseIndicatorArrays()
{
   for(int SymbolLoop=0; SymbolLoop < NumberOfTradeableSymbols; SymbolLoop++)
   {
      IndicatorRelease(MacdHandle[SymbolLoop]);
      IndicatorRelease(EmaHandle[SymbolLoop]);
      IndicatorRelease(AtrHandle[SymbolLoop]);
      IndicatorRelease(RsiHandle[SymbolLoop]);
      IndicatorRelease(DeMarkerHandle[SymbolLoop]);
      IndicatorRelease(OBVHandle[SymbolLoop]);
      IndicatorRelease(BollingerHandle[SymbolLoop]);
      IndicatorRelease(CMFHandle[SymbolLoop]);
      IndicatorRelease(ADXHandle[SymbolLoop]);
      IndicatorRelease(StochasticHandle[SymbolLoop]);
      IndicatorRelease(WilliamsRHandle[SymbolLoop]);
   }
   Print("Handle released for all symbols");   
}

//+------------------------------------------------------------------+
//| Set up RSI Handle for Multi-Symbol EA                            |
//+------------------------------------------------------------------+
bool RsiHandleMultiSymbol()
{
   for(int SymbolLoop=0; SymbolLoop < NumberOfTradeableSymbols; SymbolLoop++)
   {
      ResetLastError();
      RsiHandle[SymbolLoop] = iRSI(SymbolArray[SymbolLoop], Period(), RsiPeriod, PRICE_CLOSE); 
      if(RsiHandle[SymbolLoop] == INVALID_HANDLE)
      {
         string OutputMessage = "";
         if(GetLastError() == 4302)
            OutputMessage = ". Symbol needs to be added to the Market Watch";
         else
            StringConcatenate(OutputMessage, ". Error Code ", GetLastError());
         MessageBox("Failed to create handle for RSI indicator for " + SymbolArray[SymbolLoop] + OutputMessage);
         return false;
      }
   }
   Print("Handle for RSI for all Symbols successfully created");
   return true;
}

//+------------------------------------------------------------------+
//| Get RSI Value                                                    |
//+------------------------------------------------------------------+
double GetRsiValue(int SymbolLoop)
{
   double BufferRSI[];
   int copied = CopyBuffer(RsiHandle[SymbolLoop], 0, 0, 1, BufferRSI);
   if(copied <= 0)
   {
      Print("Failed to get RSI value for ", SymbolArray[SymbolLoop], ". Error: ", GetLastError());
      return 0;
   }
   return BufferRSI[0];
}

//+------------------------------------------------------------------+
//| Get RSI Signal                                                   |
//+------------------------------------------------------------------+
string GetRsiSignal(int SymbolLoop)
{
   double rsi = GetRsiValue(SymbolLoop);
   
   if(rsi < 25)
      return "Long";
   else if(rsi > 75)
      return "Short";
   else
      return "No Trade";
}

//+------------------------------------------------------------------+
//| Set up Macd Handle for Multi-Symbol EA                           |
//+------------------------------------------------------------------+
bool MacdHandleMultiSymbol()
{
   for(int SymbolLoop=0; SymbolLoop < NumberOfTradeableSymbols; SymbolLoop++)
   {
      ResetLastError();
      MacdHandle[SymbolLoop] = iMACD(SymbolArray[SymbolLoop],Period(),MacdFast,MacdSlow,MacdSignal,PRICE_CLOSE); 
      if(MacdHandle[SymbolLoop] == INVALID_HANDLE)
      {
         string OutputMessage = "";
         if(GetLastError() == 4302)
            OutputMessage = ". Symbol needs to be added to the Market Watch";
         else  
            StringConcatenate(OutputMessage, ". Error Code ", GetLastError()); 
         MessageBox("Failed to create handle for Macd indicator for " + SymbolArray[SymbolLoop] + OutputMessage);
         return false;
      }
   }
   Print("Handle for Macd for all Symbols successfully created"); 
   return true;     
}

//+------------------------------------------------------------------+
//| Get Macd Open Signals                                            |
//+------------------------------------------------------------------+
string GetMacdSignalOpen(int SymbolLoop)
{
   //Set symbol and indicator buffers
   const int StartCandle     = 0;
   const int RequiredCandles = 3; //How many candles are required to be stored in Expert. NOTE:[not confirmed,current confirmed, prior]
   const int IndexMacd       = 0; //Macd Line
   const int IndexSignal     = 1; //Signal Line
   double    BufferMacd[];         
   double    BufferSignal[];          
   
   //Define Macd and Signal lines, from not confirmed candle 0, for 3 candles, and store results. NOTE:[prior,current confirmed,not confirmed]
   bool      FillMacd   = CopyBuffer(MacdHandle[SymbolLoop],IndexMacd,  StartCandle,RequiredCandles,BufferMacd);
   bool      FillSignal = CopyBuffer(MacdHandle[SymbolLoop],IndexSignal,StartCandle,RequiredCandles,BufferSignal);
   if(FillMacd==false || FillSignal==false) return "Fill Error";

   //Find required Macd signal lines and normalize to 10 places to prevent rounding errors in crossovers
   double    CurrentMacd   = NormalizeDouble(BufferMacd[1],10);
   double    CurrentSignal = NormalizeDouble(BufferSignal[1],10);
   double    PriorMacd     = NormalizeDouble(BufferMacd[0],10);
   double    PriorSignal   = NormalizeDouble(BufferSignal[0],10);

   //Return Macd Long and Short Signal
   if(PriorMacd <= PriorSignal && CurrentMacd > CurrentSignal && CurrentMacd < 0 && CurrentSignal < 0)
      return   "Long";
   else if (PriorMacd >= PriorSignal && CurrentMacd < CurrentSignal && CurrentMacd > 0 && CurrentSignal > 0)
      return   "Short";
   else
      return   "No Trade";   
}

//+------------------------------------------------------------------+
//| Set up Ema Handle for Multi-Symbol EA                            |
//+------------------------------------------------------------------+
bool EmaHandleMultiSymbol()
{
   for(int SymbolLoop=0; SymbolLoop < NumberOfTradeableSymbols; SymbolLoop++)
   {
      ResetLastError();
      EmaHandle[SymbolLoop] =  iMA(SymbolArray[SymbolLoop],Period(),EmaPeriod,0,MODE_EMA,PRICE_CLOSE); 
      if(EmaHandle[SymbolLoop] == INVALID_HANDLE)
      {
         string OutputMessage = "";
         if(GetLastError() == 4302)
            OutputMessage = ". Symbol needs to be added to the Market Watch";
         else
            StringConcatenate(OutputMessage, ". Error Code ", GetLastError());
         MessageBox("Failed to create handle for Ema indicator for " + SymbolArray[SymbolLoop] + OutputMessage);
         return false;
      }
   }
   Print("Handle for Ema for all Symbols successfully created");
   return true;
}

//+------------------------------------------------------------------+
//| Get EMA Signals based off EMA line and price close - Filter      |
//+------------------------------------------------------------------+
string GetEmaOpenSignal(int SymbolLoop)
{
   //Set symbol string and indicator buffers
   const int StartCandle     = 0;
   const int RequiredCandles = 2; //How many candles are required to be stored in Expert. NOTE:[not confirmed,current confirmed]
   const int IndexEma        = 0; //Ema Line
   double    BufferEma[];         //Capture 2 candles for EMA [0,1]

   //Populate buffers for EMA line
   bool FillEma   = CopyBuffer(EmaHandle[SymbolLoop],IndexEma,StartCandle,RequiredCandles,BufferEma);
   if(FillEma==false)return("FILL_ERROR");

   //Find required EMA signal lines
   double CurrentEma = NormalizeDouble(BufferEma[1],10);
   
   //Get last confirmed candle price. NOTE:Use last value as this is when the candle is confirmed. Ask/bid gives some errors.
   double CurrentClose = NormalizeDouble(iClose(SymbolArray[SymbolLoop],Period(),0), 10);

   //Submit Ema Long and Short Trades
   if(CurrentClose > CurrentEma)
      return("Long");
   else if (CurrentClose < CurrentEma)
      return("Short");
   else
      return("No Trade");
}

//+------------------------------------------------------------------+
//| Set up ATR Handle for Multi-Symbol EA                            |
//+------------------------------------------------------------------+
bool AtrHandleMultiSymbol()
{
   for(int SymbolLoop=0; SymbolLoop < NumberOfTradeableSymbols; SymbolLoop++)
   {
      ResetLastError();
      AtrHandle[SymbolLoop] = iATR(SymbolArray[SymbolLoop], Period(), AtrPeriod); 
      if(AtrHandle[SymbolLoop] == INVALID_HANDLE)
      {
         string OutputMessage = "";
         if(GetLastError() == 4302)
            OutputMessage = ". Symbol needs to be added to the Market Watch";
         else
            StringConcatenate(OutputMessage, ". Error Code ", GetLastError());
         MessageBox("Failed to create handle for ATR indicator for " + SymbolArray[SymbolLoop] + OutputMessage);
         return false;
      }
   }
   Print("Handle for ATR for all Symbols successfully created");
   return true;
}

//+------------------------------------------------------------------+
//| Get ATR Value                                                    |
//+------------------------------------------------------------------+
double GetAtrValue(int SymbolLoop)
{
   double BufferATR[];
   if(CopyBuffer(AtrHandle[SymbolLoop], 0, 0, 1, BufferATR) <= 0)
   {
      Print("Failed to get ATR value for ", SymbolArray[SymbolLoop]);
      return 0;
   }
   return BufferATR[0];
}

//+------------------------------------------------------------------+
//| Set up DeMarker Handle for Multi-Symbol EA                       |
//+------------------------------------------------------------------+
bool DeMarkerHandleMultiSymbol()
{
   for(int SymbolLoop=0; SymbolLoop < NumberOfTradeableSymbols; SymbolLoop++)
   {
      ResetLastError();
      DeMarkerHandle[SymbolLoop] = iDeMarker(SymbolArray[SymbolLoop], Period(), DeMarkerPeriod); 
      if(DeMarkerHandle[SymbolLoop] == INVALID_HANDLE)
      {
         string OutputMessage = "";
         if(GetLastError() == 4302)
            OutputMessage = ". Symbol needs to be added to the Market Watch";
         else
            StringConcatenate(OutputMessage, ". Error Code ", GetLastError());
         MessageBox("Failed to create handle for DeMarker indicator for " + SymbolArray[SymbolLoop] + OutputMessage);
         return false;
      }
   }
   Print("Handle for DeMarker for all Symbols successfully created");
   return true;
}

//+------------------------------------------------------------------+
//| Get DeMarker Value                                               |
//+------------------------------------------------------------------+
double GetDeMarkerValue(int SymbolLoop)
{
   double BufferDeMarker[];
   if(CopyBuffer(DeMarkerHandle[SymbolLoop], 0, 0, 1, BufferDeMarker) <= 0)
   {
      Print("Failed to get DeMarker value for ", SymbolArray[SymbolLoop]);
      return 0;
   }
   return BufferDeMarker[0];
}

//+------------------------------------------------------------------+
//| Get DeMarker Signal                                              |
//+------------------------------------------------------------------+
string GetDeMarkerSignal(int SymbolLoop)
{
   double demarker = GetDeMarkerValue(SymbolLoop);
   
   if(demarker < 0.3)
      return "Long";
   else if(demarker > 0.7)
      return "Short";
   else
      return "No Trade";
}

//+------------------------------------------------------------------+
//| Set up OBV Handle for Multi-Symbol EA                            |
//+------------------------------------------------------------------+
bool OBVHandleMultiSymbol()
{
   for(int SymbolLoop=0; SymbolLoop < NumberOfTradeableSymbols; SymbolLoop++)
   {
      ResetLastError();
      OBVHandle[SymbolLoop] = iOBV(SymbolArray[SymbolLoop], Period(), VOLUME_TICK); 
      if(OBVHandle[SymbolLoop] == INVALID_HANDLE)
      {
         string OutputMessage = "";
         if(GetLastError() == 4302)
            OutputMessage = ". Symbol needs to be added to the Market Watch";
         else
            StringConcatenate(OutputMessage, ". Error Code ", GetLastError());
         MessageBox("Failed to create handle for OBV indicator for " + SymbolArray[SymbolLoop] + OutputMessage);
         return false;
      }
   }
   Print("Handle for OBV for all Symbols successfully created");
   return true;
}

//+------------------------------------------------------------------+
//| Get OBV Value                                                    |
//+------------------------------------------------------------------+
double GetOBVValue(int SymbolLoop, int shift)
{
   double BufferOBV[];
   if(CopyBuffer(OBVHandle[SymbolLoop], 0, shift, 1, BufferOBV) <= 0)
   {
      Print("Failed to get OBV value for ", SymbolArray[SymbolLoop]);
      return 0;
   }
   return BufferOBV[0];
}

//+------------------------------------------------------------------+
//| Get OBV Signal                                                   |
//+------------------------------------------------------------------+
string GetOBVSignal(int SymbolLoop)
{
   double currentOBV = GetOBVValue(SymbolLoop, 0);
   double previousOBV = GetOBVValue(SymbolLoop, 1);
   
   if(currentOBV > previousOBV)
      return "Long";
   else if(currentOBV < previousOBV)
      return "Short";
   else
      return "No Trade";
}
//+------------------------------------------------------------------+
//| Set up Bollinger Bands Handle for Multi-Symbol EA                |
//+------------------------------------------------------------------+
bool BollingerHandleMultiSymbol()
{
   for(int SymbolLoop=0; SymbolLoop < NumberOfTradeableSymbols; SymbolLoop++)
   {
      ResetLastError();
      BollingerHandle[SymbolLoop] = iBands(SymbolArray[SymbolLoop], Period(), BollingerPeriod, BollingerDeviation, 0, PRICE_CLOSE); 
      if(BollingerHandle[SymbolLoop] == INVALID_HANDLE)
      {
         string OutputMessage = "";
         if(GetLastError() == 4302)
            OutputMessage = ". Symbol needs to be added to the Market Watch";
         else
            StringConcatenate(OutputMessage, ". Error Code ", GetLastError());
         MessageBox("Failed to create handle for Bollinger Bands indicator for " + SymbolArray[SymbolLoop] + OutputMessage);
         return false;
      }
   }
   Print("Handle for Bollinger Bands for all Symbols successfully created");
   return true;
}

//+------------------------------------------------------------------+
//| Get Bollinger Bands Signal                                       |
//+------------------------------------------------------------------+
string GetBollingerSignal(int SymbolLoop)
{
   double BufferUpperBand[];
   double BufferLowerBand[];
   double currentPrice = iClose(SymbolArray[SymbolLoop], Period(), 0);

   if(CopyBuffer(BollingerHandle[SymbolLoop], 1, 0, 1, BufferUpperBand) <= 0 || CopyBuffer(BollingerHandle[SymbolLoop], 2, 0, 1, BufferLowerBand) <= 0)
   {
      Print("Failed to get Bollinger Bands value for ", SymbolArray[SymbolLoop]);
      return "No Trade";
   }

   if(currentPrice <= BufferLowerBand[0])
      return "Long";
   else if(currentPrice >= BufferUpperBand[0])
      return "Short";
   else
      return "No Trade";
}

//+------------------------------------------------------------------+
//| Set up Fibonacci Retracement Handle for Multi-Symbol EA          |
//+------------------------------------------------------------------+
bool FibonacciHandleMultiSymbol()
{
   // No specific handle needed for Fibonacci Retracement
   return true;
}

//+------------------------------------------------------------------+
//| Get Fibonacci Signal                                             |
//+------------------------------------------------------------------+
string GetFibonacciSignal(int SymbolLoop)
{
   double high = iHigh(SymbolArray[SymbolLoop], PERIOD_D1, iHighest(SymbolArray[SymbolLoop], PERIOD_D1, MODE_HIGH, 100, 0));
   double low = iLow(SymbolArray[SymbolLoop], PERIOD_D1, iLowest(SymbolArray[SymbolLoop], PERIOD_D1, MODE_LOW, 100, 0));
   double currentPrice = iClose(SymbolArray[SymbolLoop], Period(), 0);
   
   for(int i = 0; i < ArraySize(FibLevels); i++)
   {
      double fibLevel = high - (high - low) * FibLevels[i];
      if(currentPrice > fibLevel)
         return "Long";
      else if(currentPrice < fibLevel)
         return "Short";
   }
   return "No Trade";
}

//+------------------------------------------------------------------+
//| Get CMF Signal                                                   |
//+------------------------------------------------------------------+
string GetCMFSignal(int SymbolLoop)
{
   double cmf = iChaikinMoneyFlow(SymbolArray[SymbolLoop], Period(), CMFPeriod);
   Print("CMF value for ", SymbolArray[SymbolLoop], ": ", cmf);
   
   if(cmf > 0)
      return "Long";
   else if(cmf < 0)
      return "Short";
   else
      return "No Trade";
}

//+------------------------------------------------------------------+
//| Custom CMF Calculation Function                                  |
//+------------------------------------------------------------------+
double iChaikinMoneyFlow(string symbol, ENUM_TIMEFRAMES timeframe, int period)
{
   double cmf = 0.0;
   double volumeSum = 0.0;
   for(int i = 0; i < period; i++)
   {
      double high = iHigh(symbol, timeframe, i);
      double low = iLow(symbol, timeframe, i);
      double close = iClose(symbol, timeframe, i);
      double volume = iVolume(symbol, timeframe, i);
      if(high != low) // Avoid division by zero
      {
         double moneyFlowMultiplier = ((close - low) - (high - close)) / (high - low);
         double moneyFlowVolume = moneyFlowMultiplier * volume;
         cmf += moneyFlowVolume;
         volumeSum += volume;
      }
   }
   if(volumeSum != 0) // Avoid division by zero
      return cmf / volumeSum;
   else
      return 0.0;
}



//+------------------------------------------------------------------+
//| Set up ADX Handle for Multi-Symbol EA                            |
//+------------------------------------------------------------------+
bool ADXHandleMultiSymbol()
{
   for(int SymbolLoop=0; SymbolLoop < NumberOfTradeableSymbols; SymbolLoop++)
   {
      ResetLastError();
      ADXHandle[SymbolLoop] = iADX(SymbolArray[SymbolLoop], Period(), ADXPeriod); 
      if(ADXHandle[SymbolLoop] == INVALID_HANDLE)
      {
         string OutputMessage = "";
         if(GetLastError() == 4302)
            OutputMessage = ". Symbol needs to be added to the Market Watch";
         else
            StringConcatenate(OutputMessage, ". Error Code ", GetLastError());
         MessageBox("Failed to create handle for ADX indicator for " + SymbolArray[SymbolLoop] + OutputMessage);
         return false;
      }
   }
   Print("Handle for ADX for all Symbols successfully created");
   return true;
}

//+------------------------------------------------------------------+
//| Get ADX Signal                                                   |
//+------------------------------------------------------------------+
string GetADXSignal(int SymbolLoop)
{
   double BufferADX[];
   int copied = CopyBuffer(ADXHandle[SymbolLoop], 0, 0, 1, BufferADX);
   if(copied <= 0)
   {
      Print("Failed to get ADX value for ", SymbolArray[SymbolLoop], ". Error: ", GetLastError());
      return "No Trade";
   }
   
   if(BufferADX[0] > 25)
      return "Strong Trend";
   else
      return "Weak Trend";
}

//+------------------------------------------------------------------+
//| Set up Stochastic Handle for Multi-Symbol EA                     |
//+------------------------------------------------------------------+
bool StochasticHandleMultiSymbol()
{
   for(int SymbolLoop=0; SymbolLoop < NumberOfTradeableSymbols; SymbolLoop++)
   {
      ResetLastError();
      StochasticHandle[SymbolLoop] = iStochastic(SymbolArray[SymbolLoop], Period(), KPeriod, DPeriod, Slowing, MODE_SMA, STO_CLOSECLOSE); 
      if(StochasticHandle[SymbolLoop] == INVALID_HANDLE)
      {
         string OutputMessage = "";
         if(GetLastError() == 4302)
            OutputMessage = ". Symbol needs to be added to the Market Watch";
         else
            StringConcatenate(OutputMessage, ". Error Code ", GetLastError());
         MessageBox("Failed to create handle for Stochastic Oscillator indicator for " + SymbolArray[SymbolLoop] + OutputMessage);
         return false;
      }
   }
   Print("Handle for Stochastic Oscillator for all Symbols successfully created");
   return true;
}

//+------------------------------------------------------------------+
//| Get Stochastic Signal                                            |
//+------------------------------------------------------------------+
string GetStochasticSignal(int SymbolLoop)
{
   double BufferK[], BufferD[];
   int copiedK = CopyBuffer(StochasticHandle[SymbolLoop], 0, 0, 1, BufferK);
   int copiedD = CopyBuffer(StochasticHandle[SymbolLoop], 1, 0, 1, BufferD);
   if(copiedK <= 0 || copiedD <= 0)
   {
      Print("Failed to get Stochastic value for ", SymbolArray[SymbolLoop], ". Error: ", GetLastError());
      return "No Trade";
   }
   
   if(BufferK[0] < 20 && BufferD[0] < 20)
      return "Oversold";
   else if(BufferK[0] > 80 && BufferD[0] > 80)
      return "Overbought";
   else
      return "No Trade";
}

//+------------------------------------------------------------------+
//| Set up Williams %R Handle for Multi-Symbol EA                    |
//+------------------------------------------------------------------+
bool WilliamsRHandleMultiSymbol()
{
   for(int SymbolLoop=0; SymbolLoop < NumberOfTradeableSymbols; SymbolLoop++)
   {
      ResetLastError();
      WilliamsRHandle[SymbolLoop] = iWPR(SymbolArray[SymbolLoop], Period(), WilliamsRPeriod); 
      if(WilliamsRHandle[SymbolLoop] == INVALID_HANDLE)
      {
         string OutputMessage = "";
         if(GetLastError() == 4302)
            OutputMessage = ". Symbol needs to be added to the Market Watch";
         else
            StringConcatenate(OutputMessage, ". Error Code ", GetLastError());
         MessageBox("Failed to create handle for Williams %R indicator for " + SymbolArray[SymbolLoop] + OutputMessage);
         return false;
      }
   }
   Print("Handle for Williams %R for all Symbols successfully created");
   return true;
}

//+------------------------------------------------------------------+
//| Get Williams %R Signal                                           |
//+------------------------------------------------------------------+
string GetWilliamsRSignal(int SymbolLoop)
{
   double BufferWPR[];
   int copied = CopyBuffer(WilliamsRHandle[SymbolLoop], 0, 0, 1, BufferWPR);
   if(copied <= 0)
   {
      Print("Failed to get Williams %R value for ", SymbolArray[SymbolLoop], ". Error: ", GetLastError());
      return "No Trade";
   }
   
   if(BufferWPR[0] < -80)
      return "Oversold";
   else if(BufferWPR[0] > -20)
      return "Overbought";
   else
      return "No Trade";
}

//+------------------------------------------------------------------+
//| Calculate Lot Size based on Compound Risking                     |
//+------------------------------------------------------------------+
double CalculateLotSize()
{
   double lotSize;

   if (UseFixedLotSize)
   {
      lotSize = FixedLotSize;
   }
   else
   {
 // Example risk percentage
      double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      lotSize = (accountBalance * riskPercentage) / 1000; // Example calculation
   }

   // Ensure lot size is within broker's limits
   double minLotSize = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   double maxLotSize = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);

   // Normalize lot size to the nearest valid increment
   lotSize = MathMax(minLotSize, MathMin(maxLotSize, lotSize));
   lotSize = NormalizeDouble(lotSize / lotStep, 0) * lotStep;

   return lotSize;
}
//+------------------------------------------------------------------+
//| Process trades to enter buy or sell                              |
//+------------------------------------------------------------------+
bool ProcessTradeOpen(string CurrentSymbol, int SymbolLoop, ENUM_ORDER_TYPE OrderType, double &Price, double &TakeProfitPrice, double &LotSize)
{
   // Set symbol string and variables 
   int    SymbolDigits    = (int) SymbolInfoInteger(CurrentSymbol, SYMBOL_DIGITS); // note - typecast required to remove error
   double StopLossPrice   = 0.0;

   // Get minimum stop level
   double minStopLevel = SymbolInfoInteger(CurrentSymbol, SYMBOL_TRADE_STOPS_LEVEL) * SymbolInfoDouble(CurrentSymbol, SYMBOL_POINT);

   // Get ATR value
   double atr = GetAtrValue(SymbolLoop);
   // Open buy or sell orders
   if(OrderType == ORDER_TYPE_BUY)
   {
      Price           = NormalizeDouble(SymbolInfoDouble(CurrentSymbol, SYMBOL_ASK), SymbolDigits);
      StopLossPrice   = NormalizeDouble(Price - MathMax(StopLoss * atr, minStopLevel), SymbolDigits);
      TakeProfitPrice = NormalizeDouble(Price + MathMax(TakeProfit * atr, minStopLevel), SymbolDigits);
   } 
   else if(OrderType == ORDER_TYPE_SELL)
   {
       Price           = NormalizeDouble(SymbolInfoDouble(CurrentSymbol, SYMBOL_BID), SymbolDigits);
       StopLossPrice   = NormalizeDouble(Price + MathMax(StopLoss * atr, minStopLevel), SymbolDigits);
       TakeProfitPrice = NormalizeDouble(Price - MathMax(TakeProfit * atr, minStopLevel), SymbolDigits);
   }
   
   // Get lot size
   LotSize = CalculateLotSize();
   
   // Close any current positions and open new position
   Trade.PositionClose(CurrentSymbol);
   Trade.SetExpertMagicNumber(MagicNumber);
   Trade.PositionOpen(CurrentSymbol, OrderType, LotSize, Price, StopLossPrice, TakeProfitPrice, __FILE__);

   // Print successful
   Print("Trade Processed For ", CurrentSymbol, " OrderType ", OrderType, " Lot Size ", LotSize);
   
   return true;
}