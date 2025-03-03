//+------------------------------------------------------------------+
//|                                                 FxChartAI OpenEA |
//|                                        Copyright 2025, FxChartAI |
//|                                       https://www.fxchartai.com  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, FxChartAI"
#property link      "https://www.fxchartai.com"
#property version   "1.1.0"

#include <Files\File.mqh>
#include <JAson.mqh>  // JSON parser library per https://www.mql5.com/en/articles/14108

//--- Input Parameters
input double LotSize = 1;               // Risk management: Position size
input int StopLossPips = 400;              // Stop loss in pips
input int TakeProfitPips = 500;           // Take profit in pips
input int ConfidenceLevel = 5;             // Minimum confidence level required (1-5)
input int MaxDataSize = 7;                 // Maximum dataset size for analysis
input int OperationMode = 0;               // 0 = Test (CSV), 1 = Live (API)
input int MaxRetryAttempts = 9;            // Maximum data loading retry attempts
input int MagicNumber     = 12345;
input int TrailingPips = 50;

#define RETRY_DELAY_MS 60000               // 1 minute delay between retries

//--- Constants
enum SIGNAL_POSITION { SIGNAL_SELL, SIGNAL_BUY, SIGNAL_NONE };
enum TREND_WEIGHT    { TREND_HIGH, TREND_LOW, TREND_NONE };

//--- Global variables
string m10FileName = "signal_dataset_" + _Symbol + "_m10.csv";
string h1FileName  = "signal_dataset_" + _Symbol + "_h1.csv";
datetime lastM10UpdateTime = 0;
datetime lastH1UpdateTime  = 0;
int pendingOrderTicket = -1;

//--- SignalData structure
struct SignalData
  {
   datetime          time;
   SIGNAL_POSITION   position;
   TREND_WEIGHT      weight;
  };

//--- Global arrays for signal data (declared externally, e.g., in a header)
SignalData m10Data[];
int m10DataIndex = 0;
SignalData h1Data[];
int h1DataIndex = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(OperationMode != 0 && OperationMode != 1)
     { Print("Invalid OperationMode value"); return(INIT_FAILED); }
   if(MaxRetryAttempts < 1 || MaxRetryAttempts > _Period)
     { Print("Invalid MaxRetryAttempts value"); return(INIT_FAILED); }
   if(MaxDataSize < 1)
     { Print("Invalid MaxDataSize value"); return(INIT_FAILED); }
   if(ConfidenceLevel < 1)
     { Print("Invalid ConfidenceLevel value"); return(INIT_FAILED); }
   if(TakeProfitPips < 1)
     { Print("Invalid TakeProfitPips value"); return(INIT_FAILED); }
   if(StopLossPips < 1)
     { Print("Invalid StopLossPips value"); return(INIT_FAILED); }
   if(LotSize < 0)
     { Print("Invalid LotSize value"); return(INIT_FAILED); }
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   static datetime prevM10Bar = 0;
   static datetime prevH1Bar  = 0;

   if(_Period == PERIOD_M10)
     {
      datetime currentM10Bar = iTime(_Symbol, PERIOD_M10, 1);
      if(currentM10Bar != prevM10Bar)
        {
         prevM10Bar = currentM10Bar;
         ProcessTimeframe(PERIOD_M10, m10FileName, m10Data, m10DataIndex, lastM10UpdateTime);
        }
     }
   else
      if(_Period == PERIOD_H1)
        {
         datetime currentH1Bar = iTime(_Symbol, PERIOD_H1, 1);
         if(currentH1Bar != prevH1Bar)
           {
            prevH1Bar = currentH1Bar;
            ProcessTimeframe(PERIOD_H1, h1FileName, h1Data, h1DataIndex, lastH1UpdateTime);
           }
        }
  }

//+------------------------------------------------------------------+
//| Process timeframe data                                           |
//+------------------------------------------------------------------+
void ProcessTimeframe(ENUM_TIMEFRAMES tf, string filename, SignalData &data[], int &dataIndex, datetime &lastUpdate)
  {
   datetime currentTime = iTime(_Symbol, tf, 1);
   bool result = false;

   for(int attempt = 0; attempt < MaxRetryAttempts; attempt++)
     {
      if(OperationMode == 0 && LoadCSVData(filename, data, dataIndex, lastUpdate, currentTime))
        {
         result = true;
         break;
        }
      else
         if(OperationMode == 1 && LoadAPIRequest(data, dataIndex, lastUpdate, currentTime, tf))
           {
            result = true;
            break;
           }

      if(attempt < MaxRetryAttempts - 1)
        {
         Print("Load ", (OperationMode == 0 ? "test" : "live"), " data failed, retrying in 1 minute... Attempt ", attempt + 1, "/", MaxRetryAttempts);
         Sleep(RETRY_DELAY_MS);
        }
     }

   if(result)
     {
      lastUpdate = currentTime;
      AnalyzeAndTrade(tf, data);
      ManageOpenOrders(tf);
     }
   else
     {
      Print("Failed to load ", (OperationMode == 0 ? "test" : "live"), " data after ", MaxRetryAttempts, " attempts");
     }
  }

//+------------------------------------------------------------------+
//| Load CSV data using circular buffer                              |
//+------------------------------------------------------------------+
bool LoadCSVData(string filePath, SignalData &data[], int &index, datetime &lastUpdate, datetime currentTime)
  {

   int handle = FileOpen(filePath, FILE_READ|FILE_CSV|FILE_ANSI, '\n');
   if(handle == INVALID_HANDLE)
     {
      Print("Unable to load file");
      return false;
     }
   Print("Reading file");

   bool updated = false;
   while(!FileIsEnding(handle))
     {
      string line = FileReadString(handle);
      StringReplace(line, "\r", "");
      string parts[];

      if(StringSplit(line, ',', parts) == 3)
        {
         datetime dt = StringToTime(parts[0]);
         if(dt > lastUpdate && dt <= currentTime)
           {
            Print("Data found for ", currentTime);
            SignalData newData;
            newData.time = dt;
            newData.position = (SIGNAL_POSITION)StringToInteger(parts[1]);
            newData.weight = (TREND_WEIGHT)StringToInteger(parts[2]);

            // Update circular buffer
            int size = ArraySize(data);
            if(size < MaxDataSize)
               ArrayResize(data, size + 1);
            for(int x = size - 1; x > 0; x--)
               data[x] = data[x - 1];
            data[0] = newData;

            updated = true;
           }
        }
     }
   Print("Done read csv");

   FileClose(handle);
   return updated;
  }

//+------------------------------------------------------------------+
//| Function: LoadAPIRequest                                         |
//| Description: Calls FxChartAI API via GET and parses the JSON     |
//| response into an array of SignalData.                            |
//+------------------------------------------------------------------+
bool LoadAPIRequest(SignalData &data[], int &index, datetime &lastUpdate, datetime currentTime, ENUM_TIMEFRAMES timeframe)
  {
// Convert timeframe to string representation
   string tfString;
   switch(timeframe)
     {
      case PERIOD_M10:
         tfString = "M10";
         break;
      case PERIOD_H1:
         tfString = "H1";
         break;
      default:
         tfString = "M10";
         break;
     }

// Construct API URL
   string url = BuildAPIRequestURL(timeframe, currentTime);

// Send HTTP GET request
   uchar result[];
   string headers;
   string requestMethod = "GET";
   int timeout = 5000;
   string resulthHeaders;
   char postData[]; // GET request uses empty POST data
   int response = WebRequest(requestMethod,url, headers, timeout, postData, result, resulthHeaders);
   Print(CharArrayToString(result));

   if(response != 200)
     {
      Print("API request failed with error: ", GetLastError());
      return false;
     }

// Parse JSON response
   CJAVal parser;
   string jsonStr = CharArrayToString(result);

   if(!parser.Deserialize(jsonStr))
     {
      Print("Failed to parse JSON response");
      return false;
     }

   if(parser.m_type != jtARRAY)
     {
      Print("Invalid JSON structure received");
      return false;
     }

   bool dataUpdated = false;

// Process array in reverse chronological order
   for(int i = parser.Size() - 1; i >= 0; i--)
     {
      CJAVal *item = parser[i];

      // Parse trade date
      string dateStr = item["tradedate"].ToStr();
      StringReplace(dateStr, "-", ".");
      Print(dateStr);
      datetime tradeDate = StringToTime(dateStr);

      if(tradeDate <= lastUpdate)
         continue;

      // Create new signal data entry
      SignalData newData;
      newData.time = tradeDate;
      newData.position = (SIGNAL_POSITION)item["position"].ToInt();
      newData.weight = (TREND_WEIGHT)item["weight"].ToInt();

      // Update data array with new entry
      int size = ArraySize(data);
      if(size < MaxDataSize)
         ArrayResize(data, size + 1);

      // Shift existing elements
      for(int j = size - 1; j > 0; j--)
         data[j] = data[j - 1];

      data[0] = newData;
      lastUpdate = tradeDate;
      dataUpdated = true;
     }

// Maintain maximum data size
   if(ArraySize(data) > MaxDataSize)
      ArrayResize(data, MaxDataSize);

   if(ArraySize(data) > 0)
      Print("Index0: "+data[0].time);

   return dataUpdated;
  }

//+------------------------------------------------------------------+
//| Build API Request URL                                            |
//+------------------------------------------------------------------+
string BuildAPIRequestURL(ENUM_TIMEFRAMES tf, datetime time)
  {
   string timeframeStr = (tf == PERIOD_M10) ? "M10" : "H1";
   string formattedTime = TimeToString(time, TIME_DATE) + "T" +
                          TimeToString(time, TIME_MINUTES);

   return StringFormat(
             "https://chartapi.fxchartai.com/easignal?currencypair=%s&size=%d&tradedate=%s&timeframe=%s",
             _Symbol, MaxDataSize, formattedTime, timeframeStr
          );
  }
//+------------------------------------------------------------------+
//| Trend confirmation check                                         |
//+------------------------------------------------------------------+
bool IsTrendConfirmed(const SignalData &data[], int requiredConsecutive, SIGNAL_POSITION &result)
  {
   int count = 0;
   SIGNAL_POSITION lastSignal = SIGNAL_NONE;

   for(int i = 0; i < ArraySize(data); i++)
     {
      if(data[i].position == SIGNAL_NONE)
         continue;

      if(data[i].position == lastSignal)
        {
         if(++count >= requiredConsecutive)
           {
            result = data[i].position;
            return true;
           }
        }
      else
        {
         count = 1;
         lastSignal = data[i].position;
        }
     }
   return false;
  }

//+------------------------------------------------------------------+
//| Order management                                                 |
//+------------------------------------------------------------------+
void DeletePendingOrders()
  {
   for(int i = OrdersTotal()-1; i >= 0; i--)
     {
      ulong ticket = OrderGetTicket(i);
      if(ticket <= 0)
         continue;

      if(OrderGetInteger(ORDER_MAGIC) == MagicNumber &&
         (OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_STOP ||
          OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_STOP))
        {
         MqlTradeRequest req = {};
         MqlTradeResult res = {};
         req.action = TRADE_ACTION_REMOVE;
         req.order = ticket;
         OrderSend(req, res);
        }
     }
   pendingOrderTicket = -1;
  }

//+------------------------------------------------------------------+
//| Candle tail signal detection                                     |
//+------------------------------------------------------------------+
SIGNAL_POSITION GetCandleTailSignal(ENUM_TIMEFRAMES tf)
  {
   double open = iOpen(_Symbol, tf, 1);
   double close = iClose(_Symbol, tf, 1);
   double high = iHigh(_Symbol, tf, 1);
   double low = iLow(_Symbol, tf, 1);

   if(close > open)   // Bullish
     {
      double upperTail = high - close;
      double lowerTail = open - low;
      return (upperTail > lowerTail*2) ? SIGNAL_SELL :
             (lowerTail > upperTail*2) ? SIGNAL_BUY : SIGNAL_NONE;
     }

// Bearish
   double upperTail = high - open;
   double lowerTail = close - low;
   return (upperTail > lowerTail*2) ? SIGNAL_SELL :
          (lowerTail > upperTail*2) ? SIGNAL_BUY : SIGNAL_NONE;
  }

//+------------------------------------------------------------------+
//| Trendline check                                                  |
//+------------------------------------------------------------------+
bool CheckTrendline(ENUM_TIMEFRAMES tf, bool bullish)
  {
   double price = bullish ? iLow(_Symbol, tf, 1) : iHigh(_Symbol, tf, 1);
   datetime time = iTime(_Symbol, tf, 1);

   int touches = 0;
   for(int i = 2; i <= 20; i++)
     {
      double testPrice = bullish ? iLow(_Symbol, tf, i) : iHigh(_Symbol, tf, i);
      datetime testTime = iTime(_Symbol, tf, i);

      if((bullish && testPrice <= price) || (!bullish && testPrice >= price))
        {
         if(++touches >= 2)
            return true;
        }
      else
         if(iTime(_Symbol, tf, i) < time)
            break;
     }
   return false;
  }

//+------------------------------------------------------------------+
//| Execute trade                                                    |
//+------------------------------------------------------------------+
void ExecuteTrade(SIGNAL_POSITION signal, ENUM_TIMEFRAMES tf)
  {
   DeletePendingOrders();

   double price = (signal == SIGNAL_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                  : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl = StopLossPips * _Point * ((tf == PERIOD_H1) ? 10 : 1);
   double tp = TakeProfitPips * _Point * ((tf == PERIOD_H1) ? 10 : 1);

   MqlTradeRequest req = {};
   MqlTradeResult res = {};
   req.action = TRADE_ACTION_PENDING;
   req.symbol = _Symbol;
   req.volume = LotSize;
   req.type = (signal == SIGNAL_BUY) ? ORDER_TYPE_BUY_STOP : ORDER_TYPE_SELL_STOP;
   req.price = price + ((signal == SIGNAL_BUY) ? 100*_Point : -100*_Point);
   req.sl = (signal == SIGNAL_BUY) ? req.price - sl : req.price + sl;
   req.tp = (signal == SIGNAL_BUY) ? req.price + tp : req.price - tp;
   req.magic = MagicNumber;

   if(OrderSend(req, res))
      pendingOrderTicket = res.order;
  }

//+------------------------------------------------------------------+
//| Main trading logic                                               |
//+------------------------------------------------------------------+
void AnalyzeAndTrade(ENUM_TIMEFRAMES tf, const SignalData &data[])
  {
   if(PositionsTotal() > 0)
      return;

   SIGNAL_POSITION trendSignal;
   if(IsTrendConfirmed(data,ConfidenceLevel, trendSignal))
     {
      SIGNAL_POSITION candleSignal = GetCandleTailSignal(tf);
      if(candleSignal == trendSignal)
         ExecuteTrade(trendSignal, tf);
     }
  }


//+------------------------------------------------------------------+
//| Manage Open Positions                                            |
//+------------------------------------------------------------------+
void ManageOpenOrders(ENUM_TIMEFRAMES timeframe)
  {
// Process market positions
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
        {
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber)
           {
            string symbol = PositionGetString(POSITION_SYMBOL);
            ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double sl = PositionGetDouble(POSITION_SL);
            double tp = PositionGetDouble(POSITION_TP);
            double volume = PositionGetDouble(POSITION_VOLUME);
            double currentPrice = (posType == POSITION_TYPE_BUY) ?
                                  SymbolInfoDouble(symbol, SYMBOL_BID) :
                                  SymbolInfoDouble(symbol, SYMBOL_ASK);

            // Check for TP/SL hit
            if((posType == POSITION_TYPE_BUY && currentPrice >= tp) ||
               (posType == POSITION_TYPE_SELL && currentPrice <= tp))
              {
               ClosePosition(ticket);
              }
            else
               if((posType == POSITION_TYPE_BUY && currentPrice <= sl) ||
                  (posType == POSITION_TYPE_SELL && currentPrice >= sl))
                 {
                  ClosePosition(ticket);
                 }
               else
                 {
                  // Trailing stop logic
                  UpdateTrailingStop(ticket, posType, currentPrice, timeframe);
                 }
           }
        }
     }

// Process pending orders
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong orderTicket = OrderGetTicket(i);
      if(orderTicket > 0 && OrderGetInteger(ORDER_MAGIC) == MagicNumber)
        {
         CheckPendingOrderExpiry(orderTicket, timeframe);
        }
     }
  }

//+------------------------------------------------------------------+
//| Close position                                                   |
//+------------------------------------------------------------------+
bool ClosePosition(ulong ticket)
  {
   MqlTradeRequest request = {};
   MqlTradeResult result = {};

   request.action = TRADE_ACTION_DEAL;
   request.position = ticket;
   request.symbol = PositionGetString(POSITION_SYMBOL);
   request.volume = PositionGetDouble(POSITION_VOLUME);
   request.deviation = 5;
   request.type = (ENUM_ORDER_TYPE)(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
   request.price = (request.type == ORDER_TYPE_BUY) ?
                   SymbolInfoDouble(request.symbol, SYMBOL_ASK) :
                   SymbolInfoDouble(request.symbol, SYMBOL_BID);

   if(OrderSend(request, result))
     {
      Print("Position closed: ", ticket);
      return true;
     }
   else
     {
      Print("Error closing position: ", GetLastError());
      return false;
     }
  }

//+------------------------------------------------------------------+
//| Perforrm Minor Trailing stop                                     |
//+------------------------------------------------------------------+
bool performMinorTrail(ulong ticket, ENUM_POSITION_TYPE posType, double priceOpen, double currentSl, int trailingPips, ENUM_TIMEFRAMES timeframe)
  {
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   double newSl = 0.0;
   if(posType == POSITION_TYPE_BUY)
     {
      newSl = priceOpen + trailingPips * _Point;
      if(newSl > currentSl)
        {
         request.action = TRADE_ACTION_SLTP;
         request.position = ticket;
         request.symbol = PositionGetString(POSITION_SYMBOL);
         request.sl = newSl;
         request.tp = PositionGetDouble(POSITION_TP);
         if(OrderSend(request, result))
           {
            Print("Minor trailing stop updated for buy position");
            return true;
           }
        }
     }
   else
     {
      newSl = priceOpen - trailingPips * _Point;
      if(newSl < currentSl || currentSl == 0)
        {
         request.action = TRADE_ACTION_SLTP;
         request.position = ticket;
         request.symbol = PositionGetString(POSITION_SYMBOL);
         request.sl = newSl;
         request.tp = PositionGetDouble(POSITION_TP);
         if(OrderSend(request, result))
           {
            Print("Minor trailing stop updated for sell position");
            return true;
           }
        }
     }
   return false;
  }

//+------------------------------------------------------------------+
//| Perforrm Major Trailing stop                                     |
//+------------------------------------------------------------------+
bool performMajorTrail(ulong ticket, ENUM_POSITION_TYPE posType, double currentPrice, double lastCandleSize, double currentSl, int trailingPips, ENUM_TIMEFRAMES timeframe)
  {
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   double newSl = 0.0;
   double newTrailSL = 0.0;
   if(posType == POSITION_TYPE_BUY)
     {
      newSl = currentPrice - lastCandleSize;
      newTrailSL = currentPrice - trailingPips * _Point;
      newSl = (newSl < newTrailSL) ? newTrailSL : newSl;
      if(newSl > currentSl)
        {
         request.action = TRADE_ACTION_SLTP;
         request.position = ticket;
         request.symbol = PositionGetString(POSITION_SYMBOL);
         request.sl = newSl;
         request.tp = PositionGetDouble(POSITION_TP);
         if(OrderSend(request, result))
           {
            Print("Major trailing stop updated for buy position");
            return true;
           }
         else
           {
            Print("Failed: Major trailing stop for buy position");
           }
        }
     }
   else
     {
      newSl = currentPrice + lastCandleSize;
      newTrailSL = currentPrice + trailingPips * _Point;
      newSl = (newSl > newTrailSL) ? newTrailSL : newSl;
      if(newSl < currentSl || currentSl == 0)
        {
         request.action = TRADE_ACTION_SLTP;
         request.position = ticket;
         request.symbol = PositionGetString(POSITION_SYMBOL);
         request.sl = newSl;
         request.tp = PositionGetDouble(POSITION_TP);
         if(OrderSend(request, result))
           {
            Print("Major trailing stop updated for sell position");
            return true;
           }
         else
           {
            Print("Failed: Major trailing stop for sell position");
           }
        }
     }
   return false;
  }

//+------------------------------------------------------------------+
//| Update Trailing stop                                             |
//+------------------------------------------------------------------+
void UpdateTrailingStop(ulong ticket, ENUM_POSITION_TYPE posType, double currentPrice, ENUM_TIMEFRAMES timeframe)
  {
   double currentSl = PositionGetDouble(POSITION_SL);
   double priceOpen = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentProfit = PositionGetDouble(POSITION_PROFIT);
   double lastCandleHigh = iHigh(Symbol(), timeframe, 1);
   double lastCandleLow = iLow(Symbol(), timeframe, 1);
   double lastCandleSize = MathAbs(lastCandleHigh - lastCandleLow);
   int candlesOpen = (int)((TimeCurrent() - PositionGetInteger(POSITION_TIME)) / PeriodSeconds(timeframe));


   if(candlesOpen > 1 && candlesOpen <= 3 && currentProfit > 0)
     {
      performMinorTrail(ticket, posType, priceOpen, currentSl, TrailingPips, timeframe);
     }
   else
      if(candlesOpen >= 4 && currentProfit > 0)
        {
         performMajorTrail(ticket, posType, currentPrice, lastCandleSize, currentSl, TrailingPips, timeframe);
        }
  }

//+------------------------------------------------------------------+
//| Modify pending order                                             |
//+------------------------------------------------------------------+
bool ModifyPendingOrder(ulong ticket, double price, ENUM_TIMEFRAMES timeframe)
  {
   MqlTradeRequest request = {};
   MqlTradeResult result = {};

   if(OrderSelect(ticket))
     {
      double stopLoss = (timeframe == PERIOD_M10) ? StopLossPips * _Point : StopLossPips * _Point * 10;
      double takeProfit = (timeframe == PERIOD_M10) ? TakeProfitPips * _Point : TakeProfitPips * _Point * 10;

      request.action = TRADE_ACTION_MODIFY;
      request.order = ticket;
      request.price = price;
      request.sl = (OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_STOP) ? price - stopLoss : price + stopLoss;
      request.tp = (OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_STOP) ? price + takeProfit : price - takeProfit;
      request.deviation = 5;

      if(OrderSend(request, result))
        {
         Print("Pending order modified successfully");
         return true;
        }
      else
        {
         Print("ModifyPendingOrder::Error modifying orderrr: ", GetLastError());
         return false;
        }
     }
   else
     {
      Print("ModifyPendingOrder::order select failed for ticket"+ticket);
     }
   return false;
  }

//+------------------------------------------------------------------+
//| Check and delete expired pending orders                          |
//+------------------------------------------------------------------+
void CheckPendingOrderExpiry(ulong ticket, ENUM_TIMEFRAMES timeframe)
  {
   datetime expiration = OrderGetInteger(ORDER_TIME_EXPIRATION);
   if(expiration > 0 && expiration < TimeCurrent())
     {
      MqlTradeRequest request = {};
      MqlTradeResult result = {};

      request.action = TRADE_ACTION_REMOVE;
      request.order = ticket;

      if(OrderSend(request, result))
        {
         Print("Expired order removed: ", ticket);
        }
      else
        {
         Print("Error removing order: ", GetLastError());
        }
     }
  }

//+------------------------------------------------------------------+
//| Place pending order                                              |
//+------------------------------------------------------------------+
ulong PlacePendingOrder(ENUM_ORDER_TYPE orderType, double price, ENUM_TIMEFRAMES timeframe)
  {
   MqlTradeRequest request = {};
   MqlTradeResult result = {};

   double stopLoss = (timeframe == PERIOD_M10) ? StopLossPips * _Point : StopLossPips * _Point * 10;
   double takeProfit = (timeframe == PERIOD_M10) ? TakeProfitPips * _Point : TakeProfitPips * _Point * 10;

   request.action = TRADE_ACTION_PENDING;
   request.symbol = _Symbol;
   request.volume = LotSize;
   request.type = orderType;
   request.price = price;
   request.sl = (orderType == ORDER_TYPE_BUY_STOP) ? price - stopLoss : price + stopLoss;
   request.tp = (orderType == ORDER_TYPE_BUY_STOP) ? price + takeProfit : price - takeProfit;
   request.deviation = 5;
   request.magic = MagicNumber;

   if(OrderSend(request, result))
     {
      Print("Pending order placed: ", result.order);
      return result.order;
     }
   else
     {
      Print("Error placing order: ", GetLastError());
      return 0;
     }
  }
//+------------------------------------------------------------------+
