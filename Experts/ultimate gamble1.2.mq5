//+------------------------------------------------------------------+
//|                                              ultimate gamble.mq5 |
//|                                  Copyright 2021, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2021, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#include <gride-martingale.mqh>
#include <lib_cisnewbar.mqh>
//#include <trailing stop.mqh>
#include <Trade\Trade.mqh>


CTrade trade;
input string label = "Something";
input int bbPeriod = 21;
input double bbDeviation = 1.9;
input double flatFactor = 1.9;
input int atrPeriod = 14;
input ENUM_TIMEFRAMES tf = PERIOD_CURRENT;
input int      Margin_Chk=0;     // Check Margin before placing trade(0=No, 1=Yes)
input double   Trd_percent=15.0;
input double lotSize = 0.2;
input bool recoveryMode = true;
input int maxTrades = 10;
input int kamaPeriod = 14;
input int fastEndPeriod = 2;
input int slowEndPeriod = 30;
input double smoothPower = 2;
input int filter = 50;
input int filterPeriod = 4;
input double filterDifference = 50  ;
input ENUM_APPLIED_PRICE price = PRICE_CLOSE;
bool isSell = false;
bool isBuy = false;
bool closeCondition = false;
string tradeType;
sinput int EA_Magic = 12345;
int STP,TKP;
int breakEvnPnt = 200;
string signal = "";
bool buyGrids= false;
bool sellGrids = false;
CisNewBar  newBar;
GMexpert   gmExpert;


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
      newBar.SetPeriod(tf);
      gmExpert.doInit(label,bbPeriod,bbDeviation,bbDeviation,atrPeriod,kamaPeriod,fastEndPeriod,slowEndPeriod,smoothPower,filter,filterPeriod,filterDifference,price);
      gmExpert.setLotSize(lotSize);
      gmExpert.setMaxTrades(maxTrades);
      gmExpert.setRecoveryMode(recoveryMode);
      gmExpert.setSymbol(_Symbol);
      gmExpert.setTradePct(Trd_percent);
      gmExpert.setCheckMg(Margin_Chk);
   
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
//---
      double Bid = NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_BID),_Digits);
      double Ask = NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_ASK),_Digits);
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
         
         if(isBuy)
         {  
           sellGrids = false;
           if(buyGrids == false)
           {   
              double tp = Ask + 50;
              int atrval = gmExpert.atrValue();
              for(int i= 1; i< maxTrades+1; i++)
              {
               trade.BuyStop(0.2,Ask+(atrval*i),_Symbol,Ask+(atrval*i)- 30,Ask+(atrval*i)+30,ORDER_TIME_GTC,0,NULL);
               //trade.SellStop(0.2,Ask+(atrval*i),_Symbol,0,0,ORDER_TIME_GTC,0,NULL);
              }
              buyGrids = true;
              
           }
           
               
         
         }if(isSell)
         {
           buyGrids = false;
           if(sellGrids == false)
           {
              int atrval = gmExpert.atrValue();
              //int tp = Bid - 50;
              for(int i= 1; i< maxTrades+1; i++)
              {
               trade.SellStop(0.2,Bid-(atrval*i),_Symbol,Bid-(atrval*i)+30,Bid-(atrval*i)-30,ORDER_TIME_GTC,0,NULL);
              }
              sellGrids = true;
            }
           
         }
         closeCondition = gmExpert.checkCloseCondition();
          if (closeCondition)
            {
               //trade.PositionClose(_Symbol,10);
               //Print("does it get to here");
               
               closeAllBuyPositions();
               closeAllSellPositions();
               //Print("Thsi is where ------------------------------------------------>");
               
               if (recoveryMode == true)// should be based on two more out the loop indicators i.e stochastic can be a timeframe lower for faster execution
                {
                  // a check flag to see if its time to trade a martingale
                  
                  Print("This is martingale lol -------------------------------------------------------> XD");
                  
                  bool isrecSell = gmExpert.checkSell();
                  bool isrecBuy = gmExpert.checkBuy();
                  
                  // get lot size to use with 1.5 atr value to recover loss
                  
                  gmExpert.setLotMultiplier();
                  string ordType = gmExpert.previousOrderType();
                  // Know in which direction are we making the trade
                  if ((isrecBuy)&& (ordType == "sell"))
                  {  
                  
                     Print("This is the desired lot size ---------------------------lol --------------------xD--->", gmExpert.getLotSizeMg());
                     int atrval = gmExpert.atrValue();
                     double lott = gmExpert.getLotSizeMg();
                     trade.Buy(lott,_Symbol,Ask,0,Ask + atrval,NULL);
                  }
                  else if((isrecSell)&& (ordType == "buy"))
                  {
                     int atrval = gmExpert.atrValue();
                     double lott = gmExpert.getLotSizeMg();
                     trade.Sell(lott,_Symbol,Bid,0,Bid - atrval,NULL);
                  }
                // check whether previous grids were buys or losses
                // check whether 
                  
                }
               
               
            }
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
   if (mrate[1].close > mrate[1].open)
   {
      signal ="buy";
      return signal;
   }
   else if (mrate[1].close < mrate[1].open)
   {
      signal = "sell";
      return signal;
   }
   else
   {
      return "nothing";
   }
}

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
  
  
void checkTrailingStop(double Bid, int trailingStpPnt, int trailStpMove)
{
   double SL = NormalizeDouble(Bid+trailStpMove,_Digits);
   
   for (int i = PositionsTotal()-1; i>= 0; i--)
   {
      string symbol  = PositionGetSymbol(i);
      
      if(_Symbol == symbol)
      {
         ulong PositionTicket =  PositionGetInteger(POSITION_TICKET);
         double CurrentStopLoss = PositionGetDouble(POSITION_SL);
         
         if (CurrentStopLoss > SL)
         {
            trade.PositionModify(PositionTicket,(CurrentStopLoss - trailingStpPnt),0);
         }
      }
   }
}


  
void checkTrailingStopbuy(double Ask, int trailingStpPnt, int trailStpMove)
{
   double SL = NormalizeDouble(Ask-trailStpMove,_Digits);
   
   for (int i = PositionsTotal()-1; i>= 0; i--)
   {
      string symbol  = PositionGetSymbol(i);
      
      if(_Symbol == symbol)
      {
         ulong PositionTicket =  PositionGetInteger(POSITION_TICKET);
         double CurrentStopLoss = PositionGetDouble(POSITION_SL);
         
         if (CurrentStopLoss < SL)
         {
            trade.PositionModify(PositionTicket,(CurrentStopLoss - trailingStpPnt),0);
         }
      }
   }
}


void closeAllBuyPositions()
{
   for (int i= PositionsTotal()-1; i>=0; i--)
   {
   
      //Get the ticket number for the current position
      int ticket = PositionGetTicket(i);
      int PositionDirection= PositionGetInteger(POSITION_TYPE);
      
      // if it is buy position
      
      if (PositionDirection == POSITION_TYPE_BUY)
      {
         trade.PositionClose(ticket);
      }
   }

}


void closeAllSellPositions()
{
   for (int i= PositionsTotal()-1; i>=0; i--)
   {
   
      //Get the ticket number for the current position
      int ticket = PositionGetTicket(i);
      int PositionDirection= PositionGetInteger(POSITION_TYPE);
      
      // if it is buy position
      
      if (PositionDirection == POSITION_TYPE_SELL)
      {
         trade.PositionClose(ticket);
      }
   }

}

void closeAllBuyStops()
{
   ulong ticket;
   int positionType;
   for (int i = OrdersTotal()-1; i>=0; i--)
   {
      ticket = OrderGetTicket(i);
      positionType = OrderGetInteger(ORDER_TYPE);
      if (positionType == ORDER_TYPE_BUY_STOP)
      {
         trade.OrderDelete(ticket);
      }
   }
}

void closeAllSellStops()
{
   ulong ticket;
   int positionType;
   for (int i = OrdersTotal()-1;i>=0; i--)
   {
      ticket = OrderGetTicket(i);
      positionType = OrderGetInteger(ORDER_TYPE);
      if (positionType == ORDER_TYPE_SELL_STOP)
      {
         trade.OrderDelete(ticket);
      }
   }
}


void closeAllBuyLimits()
{
   ulong ticket;
   int positionType;
   for (int i = OrdersTotal()-1;i>=0; i--)
   {
      ticket = OrderGetTicket(i);
      positionType = OrderGetInteger(ORDER_TYPE);
      if (positionType == ORDER_TYPE_BUY_LIMIT)
      {
         trade.OrderDelete(ticket);
      }
   }
}


void closeAllSellLimit()
{
   ulong ticket;
   int positionType;
   for (int i = OrdersTotal()-1;i>=0; i--)
   {
      ticket = OrderGetTicket(i);
      positionType = OrderGetInteger(ORDER_TYPE);
      if (positionType == ORDER_TYPE_SELL_LIMIT)
      {
         trade.OrderDelete(ticket);
      }
   }
}
