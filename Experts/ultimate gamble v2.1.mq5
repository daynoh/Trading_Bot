//+------------------------------------------------------------------+
//|                                              ultimate gamble.mq5 |
//|                                  Copyright 2021, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2021, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#include <gride-martingale[2].mqh>
#include <lib_cisnewbar.mqh>
#include <martingale2.mqh>
//#include <trailing stop.mqh>
#include <Trade\Trade.mqh>
#include <Dictionary.mqh>


//CTrade trade;
input maswitch inPeriod = MODE_SMA;
input int fastMaPeriod = 2;
input int slowMaPeriod = 30;
input int cmoPeriod = 9;
input ENUM_APPLIED_PRICE apPrice = PRICE_CLOSE;
input string label = "Something";
input int bbPeriod = 21;
input double bbDeviation = 1.9;
input double flatFactor = 1.9;
input int atrPeriod = 14;
input ENUM_TIMEFRAMES tf = PERIOD_CURRENT;
input ENUM_TIMEFRAMES stoTf = PERIOD_M30;
input ENUM_TIMEFRAMES maTf = PERIOD_M15;
input int maPeriod = 20;
input int      Margin_Chk=0;     // Check Margin before placing trade(0=No, 1=Yes)
input double   Trd_percent=15.0;
input double lotSize = 0.2;
bool recoveryMode = true;
input int maxTrades = 7;
input ENUM_APPLIED_PRICE price = PRICE_CLOSE;
input int k = 5;
input int s = 3;
input int d = 3;
input int takeProfit = 100;
input int stopLoss = 30;
bool isSell = false;
bool isBuy = false;
bool isRange = false;
bool closeCondition = false;
bool periodEnd = false;
string tradeType;
sinput int EA_Magic = 12345;
int STP,TKP;
int breakEvnPnt = 200;
string signal = "";
bool buyGrids= false;
bool sellGrids = false;
int prevOpenTrades = 0;
string prevMtTrade = "";
bool prevMtSell = false;
bool prevMtBuy = false;  

bool prevbuy = true;
bool mtBuy = false;
bool mtSell = false;


input ENUM_TIMEFRAMES recoveryTf = PERIOD_M20;
double currentLoss = 0;
CisNewBar  newBar;
GMexpert   gmExpert;
Martingale  martingale;


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   trade.SetExpertMagicNumber(EA_Magic);
   newBar.SetPeriod(tf);
   gmExpert.doInit(label,bbPeriod,bbDeviation,bbDeviation,atrPeriod,price,
                   stoTf,k,s,d,maTf,inPeriod,maPeriod,fastMaPeriod,slowMaPeriod,cmoPeriod,apPrice);
   gmExpert.setLotSize(lotSize);
   gmExpert.setMaxTrades(maxTrades);
   gmExpert.setRecoveryMode(recoveryMode);
   gmExpert.setSymbol(_Symbol);
   gmExpert.setTradePct(Trd_percent);
   gmExpert.setCheckMg(Margin_Chk);
   
   martingale.doInit(stoTf,k,d,s,recoveryTf,inPeriod,maPeriod*4,fastMaPeriod,slowMaPeriod,cmoPeriod,apPrice);
   

//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   gmExpert.doUnInit();
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {

                        
//--- define some MQL5 Structures we will use for our trade
//breakEven(breakEvnPnt);
   MqlTick latest_price;      // To be used for getting recent/latest price quotes
   MqlRates mrate[];          // To be used to store the prices, volumes and spread of each bar
   static double nextBuyPrice; // to store the next buy price for the grid
   static double nextSellPrice;


//CheckTrailingStop(trailingStpPnt);
//--- the rates arrays
   ArraySetAsSeries(mrate,true);


   if(!SymbolInfoTick(_Symbol,latest_price))
     {
      Alert("Error getting the latest price quote - error:",GetLastError(),"!!");
      return;
     }

//--- get the details of the latest 3 bars
   if(CopyRates(_Symbol,tf,0,3,mrate)<0)
     {
      Alert("Error copying rates/history data - error:",GetLastError(),"!!");

     }

   if(newBar.isNewBar()>0)
     {

      Print("This is the open orders profit and returns ---------------------------------------------------->",
            gmExpert.openPositionsProfitLoss());
      STP = gmExpert.calculateSl();
      TKP = gmExpert.calculateTp();

      isSell = gmExpert.checkSell();
      isBuy  = gmExpert.checkBuy();
      isRange = gmExpert.checkRange();
      periodEnd = gmExpert.checkPeriodEnd();
      
      bool internalBuy = false;
      // check the number of open trades// open grids
      int nOpTrades = CountOpenTrades(EA_Magic);
      // check the number of pending orders
      Print("##################################$#########################################################");
      Print("This is number of open trades D: ",nOpTrades);
      int nOpPendingOrds = CountPendingOrders(EA_Magic);
      // checks the number of grids remaining to open when we get an additional activation signal
      Print("############$$$$$$$$$$$$$$$$$$$$$#######################$$$$$$$$$$$$$$$$$$$@################$#");
      Print("This is number of pending orders :", nOpPendingOrds);
      int opOrds = maxTrades -(nOpTrades + nOpPendingOrds);
      
      Print("###################$$$$$$$$$$$$$$$$$$$$$%%$$$$$$$$$$$$$$$$$###########################$###");
      Print("This is number of allowed pending orders left", opOrds);
      Print("This is number of open trades : ",nOpTrades, "Print this is number of prev open trades : ", prevOpenTrades);
      
      // checking period end and last grid loss function
      if((nOpTrades == 0) && (prevOpenTrades > 0))
      {
         double returns = gmExpert.lastPositionGridLoss(prevOpenTrades);
         Print("$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$ This is close order loss =--------------------------> :", returns);
         if (returns < 0)
         {
            recoveryMode = false;
            currentLoss = returns;
            martingale.set_loss(currentLoss);
            martingale.set_atrVal(gmExpert.atrValue());
              
         }
         else
         {
            recoveryMode = false;
         }
       
      }
         
      
      
      if(gmExpert.checkBuyExit())
         {
            closeAllBuyStops();
            closeAllBuyPositions();
         }
      if(isBuy)
      {  
         
        
          // Check unactivated oposite and close pending orders
         closeAllSellStops();
         internalBuy = gmExpert.checkIntBuy();
         //Check the direction of open trades
         //bool opTrades = OpenTrades(); wait till I know what i want to do with you
         
         bool internalBuy = gmExpert.checkIntBuy();
         bool internalClose = gmExpert.checkIntBuyOpp();
         //
         bool thisIsFirst = prevbuy;
         prevbuy  = false;
         // open grids 
         if (thisIsFirst)
         {
            openGrids("buy",maxTrades);
         }
         
         // 
         if(internalBuy)
         {
            openGrids("buy",opOrds);
         }
         
         else if(internalClose) 
         {
            closeAllBuyStops();
         }
         
         
         
         
         
         
      }
      
      if(isSell)
      {
         CloseAllOrders();
         closeAllBuyStops();
         prevbuy = true;
      }
      
      if (isRange)
      {
         prevbuy = true;
      
      }
      
      
     
      
      if(recoveryMode)
      {  
      
         Print("This is recovery mode..........===============================");
         mtBuy = martingale.checkBuy();
         mtSell = martingale.checkSell();
         double mtLot = martingale.calculateLotSize();
         Print("This is the expected lot size :----------- <>  ", mtLot);
         Print("This martingale mtSell -------->  ", mtSell);
         Print("This martingale mtBuy  -------->  ", mtBuy);
         
         if(mtBuy)
         {
            double mtLot = martingale.calculateLotSize();
            martingale.buy(mtLot);
         }
         if(mtSell)
         {
            double mtLot = martingale.calculateLotSize();
            martingale.sell(mtLot);
         }
        
      }
      
       prevOpenTrades = nOpTrades;


      
     }


  }
//+------------------------------------------------------------------+
//| Trade function                                                   |
//+------------------------------------------------------------------+
void OnTrade()
  {
//---

  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string checkEntrySignal()
  {
   MqlRates mrate[];          // To be used to store the prices, volumes and spread of each bar

//CheckTrailingStop(trailingStpPnt);
//--- the rates arrays
   ArraySetAsSeries(mrate,true);
//--- get the details of the latest 3 bars
   if(CopyRates(_Symbol,tf,0,3,mrate)<0)
     {
      Alert("Error copying rates/history data - error:",GetLastError(),"!!");
     }
// buy when candle is bullish
   if(mrate[1].close > mrate[1].open)
     {
      signal ="buy";
      return signal;
     }
   else
      if(mrate[1].close < mrate[1].open)
        {
         signal = "sell";
         return signal;
        }
      else
        {
         return "nothing";
        }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CloseAllOrders()
  {

   Print("This should be a close----------------------------------------------> close");
//--- declare and initialize the trade request and result of trade request
   MqlTradeRequest request;
   MqlTradeResult  result;
   int total=PositionsTotal(); // number of open positions
//--- iterate over all open positions
   for(int i=total-1; i>=0; i--)
     {
      //--- parameters of the order
      ulong  position_ticket=PositionGetTicket(i);                                      // ticket of the position
      string position_symbol=PositionGetString(POSITION_SYMBOL);                        // symbol
      int    digits=(int)SymbolInfoInteger(position_symbol,SYMBOL_DIGITS);              // number of decimal places
      ulong  magic=PositionGetInteger(POSITION_MAGIC);                                  // MagicNumber of the position
      double volume=PositionGetDouble(POSITION_VOLUME);                                 // volume of the position
      ENUM_POSITION_TYPE type=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);    // type of the position
      //--- output information about the position
      PrintFormat("#%I64u %s  %s  %.2f  %s [%I64d]",
                  position_ticket,
                  position_symbol,
                  EnumToString(type),
                  volume,
                  DoubleToString(PositionGetDouble(POSITION_PRICE_OPEN),digits),
                  magic);
      //--- if the MagicNumber matches
      if(magic==EA_Magic)
        {
         //--- zeroing the request and result values
         ZeroMemory(request);
         ZeroMemory(result);
         //--- setting the operation parameters
         request.action   =TRADE_ACTION_DEAL;        // type of trade operation
         request.position =position_ticket;          // ticket of the position
         request.symbol   =position_symbol;          // symbol
         request.volume   =volume;                   // volume of the position
         request.deviation=5;                        // allowed deviation from the price
         request.magic    =EA_Magic;             // MagicNumber of the position
         //--- set the price and order type depending on the position type
         if(type==POSITION_TYPE_BUY)
           {
            request.price=SymbolInfoDouble(position_symbol,SYMBOL_BID);
            request.type =ORDER_TYPE_SELL;
           }
         else
           {
            request.price=SymbolInfoDouble(position_symbol,SYMBOL_ASK);
            request.type =ORDER_TYPE_BUY;
           }
         //--- output information about the closure
         PrintFormat("Close #%I64d %s %s",position_ticket,position_symbol,EnumToString(type));
         //--- send the request
         if(!OrderSend(request,result))
            PrintFormat("OrderSend error %d",GetLastError());  // if unable to send the request, output the error code
         //--- information about the operation
         PrintFormat("retcode=%u  deal=%I64u  order=%I64u",result.retcode,result.deal,result.order);
         //---
        }
     }
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void checkTrailingStop(double Bid, int trailingStpPnt, int trailStpMove)
  {
   double SL = NormalizeDouble(Bid+trailStpMove,_Digits);

   for(int i = PositionsTotal()-1; i>= 0; i--)
     {
      string symbol  = PositionGetSymbol(i);

      if(_Symbol == symbol)
        {
         ulong PositionTicket =  PositionGetInteger(POSITION_TICKET);
         double CurrentStopLoss = PositionGetDouble(POSITION_SL);

         if(CurrentStopLoss > SL)
           {
            trade.PositionModify(PositionTicket,(CurrentStopLoss - trailingStpPnt),0);
           }
        }
     }
  }



//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void checkTrailingStopbuy(double Ask, int trailingStpPnt, int trailStpMove)
  {
   double SL = NormalizeDouble(Ask-trailStpMove,_Digits);

   for(int i = PositionsTotal()-1; i>= 0; i--)
     {
      string symbol  = PositionGetSymbol(i);

      if(_Symbol == symbol)
        {
         ulong PositionTicket =  PositionGetInteger(POSITION_TICKET);
         double CurrentStopLoss = PositionGetDouble(POSITION_SL);

         if(CurrentStopLoss < SL)
           {
            trade.PositionModify(PositionTicket,(CurrentStopLoss - trailingStpPnt),0);
           }
        }
     }
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void closeAllBuyPositions()
  {
   for(int i= PositionsTotal()-1; i>=0; i--)
     {

      //Get the ticket number for the current position
      int ticket = PositionGetTicket(i);
      int PositionDirection= PositionGetInteger(POSITION_TYPE);

      // if it is buy position

      if(PositionDirection == POSITION_TYPE_BUY)
        {
         trade.PositionClose(ticket);
        }
     }

  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void closeAllSellPositions()
  {
   for(int i= PositionsTotal()-1; i>=0; i--)
     {

      //Get the ticket number for the current position
      int ticket = PositionGetTicket(i);
      int PositionDirection= PositionGetInteger(POSITION_TYPE);

      // if it is buy position

      if(PositionDirection == POSITION_TYPE_SELL)
        {
         trade.PositionClose(ticket);
        }
     }

  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void closeAllBuyStops()
  {
   ulong ticket;
   int positionType;
   for(int i = OrdersTotal()-1; i>=0; i--)
     {
      ticket = OrderGetTicket(i);
      positionType = OrderGetInteger(ORDER_TYPE);
      if(positionType == ORDER_TYPE_BUY_STOP)
        {
         trade.OrderDelete(ticket);
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void closeAllSellStops()
  {
   ulong ticket;
   int positionType;
   for(int i = OrdersTotal()-1; i>=0; i--)
     {
      ticket = OrderGetTicket(i);
      positionType = OrderGetInteger(ORDER_TYPE);
      if(positionType == ORDER_TYPE_SELL_STOP)
        {
         trade.OrderDelete(ticket);
        }
     }
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void closeAllBuyLimits()
  {
   ulong ticket;
   int positionType;
   for(int i = OrdersTotal()-1; i>=0; i--)
     {
      ticket = OrderGetTicket(i);
      positionType = OrderGetInteger(ORDER_TYPE);
      if(positionType == ORDER_TYPE_BUY_LIMIT)
        {
         trade.OrderDelete(ticket);
        }
     }
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void closeAllSellLimit()
  {
   ulong ticket;
   int positionType;
   for(int i = OrdersTotal()-1; i>=0; i--)
     {
      ticket = OrderGetTicket(i);
      positionType = OrderGetInteger(ORDER_TYPE);
      if(positionType == ORDER_TYPE_SELL_LIMIT)
        {
         trade.OrderDelete(ticket);
        }
     }
  }
//+------------------------------------------------------------------+

int CountPendingOrders(int magicNo)
{
   int TodayslimitedOrders = 0;

   for(int i=0; i<OrdersTotal(); i++)
   {
      
      string OrderSymbol = OrderGetString(ORDER_SYMBOL);
      int Magic = OrderGetInteger(ORDER_MAGIC);
      
      OrderSelect(OrderGetTicket(i));
      if(OrderSymbol == Symbol())
      //if(Magic == magicNo )
      {
        ENUM_ORDER_TYPE type=(ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
        if(type==ORDER_TYPE_BUY_STOP || type==ORDER_TYPE_SELL_STOP)
        TodayslimitedOrders ++;
      }
   }
   return(TodayslimitedOrders);

}

int CountOpenTrades(int magicNo)

{
   int openOrders = 0;

   for(int i=0; i<PositionsTotal(); i++)
   {
      string OrderSymbol = PositionGetSymbol(i);
      
      int Magic = PositionGetInteger(POSITION_MAGIC);
      
      PositionSelectByTicket(PositionGetTicket(i));
      if(OrderSymbol == Symbol())
      //if(Magic == magicNo )
      {
        Print("$$$$$$$$$$$$$$$$$$$%%%%%%%%%%%%%%%%%%%%%%%%%%Does it get upto here");
        ENUM_ORDER_TYPE type=(ENUM_ORDER_TYPE)PositionGetInteger(POSITION_TYPE);
        if(type==ORDER_TYPE_BUY || type==ORDER_TYPE_SELL)
        openOrders++;
      }
   }
   return(openOrders);

}


void openGrids(string ordType, int maxt)
{
   double Bid = NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_BID),_Digits);
   double Ask = NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_ASK),_Digits);
   if(ordType == "buy")
      {  
      
        double tp = Ask + 100;
        int atrval = gmExpert.atrValue();
        if (maxt == 1)
        {
           
           trade.Buy(0.2,NULL,Ask,0,tp,NULL);
        }
        
        else if (maxt > 1 )
        {
         for(int i= 1; i< maxt+1; i++)
           {
            trade.BuyStop(0.2,Ask+(10*i),_Symbol,0,tp,ORDER_TIME_GTC,Bid -40,NULL);
            //trade.SellStop(0.2,Ask+(atrval*i),_Symbol,0,0,ORDER_TIME_GTC,0,NULL);
           }
         
        
        }else 
        {
        
        }
        
   
      } 
    else if (ordType == "sell")
       {
       
       int atrval = gmExpert.atrValue();
       
       double tp = Bid - 100;
        if (maxt == 1)
        {
            
            trade.Sell(0.2,NULL,Bid,Bid+40,tp,NULL );
        }
        else if (maxt>1)
        
        {
            for(int i= 1; i< maxt+1; i++)
        
        
           {
            trade.SellStop(0.2,Bid-(10*i),_Symbol,Ask+40,tp,ORDER_TIME_GTC,0,NULL);
           } 
        }
        
       }
}