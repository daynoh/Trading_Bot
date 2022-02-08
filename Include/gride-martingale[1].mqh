//+------------------------------------------------------------------+
//|                                       gride-martingale class.mqh |
//|                        Copyright 2021, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2021, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
//+------------------------------------------------------------------+
//| defines                                                          |
//+------------------------------------------------------------------+
// #define MacrosHello   "Hello, world!"
// #define MacrosYear    2010
//+------------------------------------------------------------------+
//| DLL imports                                                      |
//+------------------------------------------------------------------+
// #import "user32.dll"
//   int      SendMessageA(int hWnd,int Msg,int wParam,int lParam);
// #import "my_expert.dll"
//   int      ExpertRecalculate(int wParam,int lParam);
// #import
//+------------------------------------------------------------------+
//| EX5 imports                                                      |
//+------------------------------------------------------------------+
// #import "stdlib.ex5"
//   string ErrorDescription(int error_code);
// #import
//+------------------------------------------------------------------+
enum maswitch
  {
   Simple=MODE_SMA,
   Exponential=MODE_EMA,
   Smoothed=MODE_SMMA,
   LinearWeighted=MODE_LWMA,
   AMA=IND_AMA,
   DEMA=IND_DEMA,
   FRAMA=IND_FRAMA,
   TEMA=IND_TEMA,
   VIDYA=IND_VIDYA
  };
class GMexpert
{  // initialize private members
   private:
      double tradePct;        // percentage of account to trade
      int Chk_Margin; //Margin Check before placing trade? (1 or 0)
      int magicNo;
      double lotSize;
      double lotSizeMultiplier;
      bool recoveryMode;
      double lotSizeMg;
      int maxTrades;
      // experimental parameter
      // int mgMax;
      int    maHandle;
      
      double maBuffer[];
      
      double rexMain[];
      double rexSignal[];
      int atrHandle;
      double atr[];
      int bbTrendHandle;
      double bbTrend[];
      int kamaHandle;
      double kama[];
      
      int mtfStochasticHandle;
      double mtfStochMain[];
      double mtfStochSig[];
      MqlTradeRequest trequest;
      MqlTradeResult tresult;
      string symbol;
      ENUM_TIMEFRAMES tf;
      string errorMsg;
      int errorCode;
      
   public:
      void  GMexpert();                // class constructer
      void  setSymbol(string syb){symbol = syb;}
      void  setLotSize(double lot){lotSize = lot;}
      void  setLotMultiplier(double returns);
      void  setRecoveryMode(bool mode){recoveryMode = mode;}
      void  setMaxTrades(int maxtrade){maxTrades = maxtrade;}
      void  setTradePct(double pct){tradePct = pct;}
      void  setMagic(int magic){magicNo = magic;}
      void  setLotsizeMg(int lotMg){lotSizeMg = lotMg;}
      void  setCheckMg(int mg){Chk_Margin = mg;}
      string  previousOrderType();
      double  getLotSizeMg(){return lotSizeMg;}
      double lastPositionGridLoss(int prevTrades);
      void  doInit(string label,int bbPeriod, double bbDeviation,
                     double flatFactor,int atrPeriod, int kamaPeriod,
                     int fastEndPeriod,int slowEndPeriod,double smoothPower,
                     int filter,int filterPeriod, double filterDifference,
                     ENUM_APPLIED_PRICE price,
                     ENUM_TIMEFRAMES stochTf, int k, int d, int s
                     ,ENUM_TIMEFRAMES maTf,maswitch inpPeriod,int maPeriod,
                     int fastMaPeriod,int slowMaPeriod,int cmoPeriod,ENUM_APPLIED_PRICE apPrice);
      int  calculateSl();
      int  calculateTp();
      void  doUnInit();
      bool checkBuy();
      bool checkSell();
      bool checkCloseCondition();
      bool checkBuyGridSignal();
      bool checkRange();
      bool checkIntBuyOpp();
      bool checkIntSellOpp();
      bool checkSellGridSignal();
      bool checkIntBuy();
      bool checkIntSell();
      bool checkPeriodEnd();
      bool checkBuyExit();
      bool checkSellExit();
      int atrValue();
      void openBuy(ENUM_ORDER_TYPE otype,double askprice,double SL,double TP,int dev,string comment="");
      void openSell(ENUM_ORDER_TYPE otype,double bidprice,double SL,double TP,int dev,string comment="");
      double openPositionsProfitLoss();
  protected:
      void  showError(string msg, int ercode);           //function for use to display error messages
      void  getBuffers();                                //function for getting Indicator buffers
      bool  MarginOK(double lotSize);                                  //function to check if margin required for lots is OK
      
};

// creating code for the constructer to initialize values
//+------------------------------------------------------------------+
void GMexpert::showError(string msg,int ercode)
  {
   Alert(msg,"-error:",ercode,"!!"); // display error
  }

void GMexpert::GMexpert()
{
   ZeroMemory(trequest);
   ZeroMemory(tresult);
   ZeroMemory(bbTrend);
   ZeroMemory(atr);
   ZeroMemory(mtfStochMain);
   ZeroMemory(mtfStochSig);
   ZeroMemory(maBuffer);
 
   errorMsg = "";
   errorCode = 0;

}

//| MARGINOK FUNCTION                                                |
//| *No input parameters                                             |
//| *Uses the Class data members to check margin required to place   |
//| a trade with the lot size is ok                                  |
//| *Returns TRUE on success and FALSE on failure                    |
//+------------------------------------------------------------------+
bool GMexpert::MarginOK(double lotsize)
  {
   double one_lot_price;                                                        //Margin required for one lot
   double act_f_mag     = AccountInfoDouble(ACCOUNT_FREEMARGIN);                //Account free margin
   long   levrage       = AccountInfoInteger(ACCOUNT_LEVERAGE);                 //Leverage for this account
   double contract_size = SymbolInfoDouble(symbol,SYMBOL_TRADE_CONTRACT_SIZE);  //Total units for one lot
   string base_currency = SymbolInfoString(symbol,SYMBOL_CURRENCY_BASE);        //Base currency for currency pair
                                                                                //
   if(base_currency=="USD")
     {
      one_lot_price=contract_size/levrage;
     }
   else
     {
      double bprice= SymbolInfoDouble(symbol,SYMBOL_BID);
      one_lot_price=bprice*contract_size/levrage;
     }
// Check if margin required is okay based on setting
   if(MathFloor(lotsize*one_lot_price)>MathFloor(act_f_mag*tradePct))
     {
      return(false);
     }
   else
     {
      return(true);
     }
  }


void GMexpert::doInit(string label,int bbPeriod, double bbDeviation, 
                        double bbFlat,int atrPeriod,int kamaPeriod,int fastEndPeriod,
                        int slowEndPeriod,double smoothPower,int filter,int filterPeriod,
                         double filterDifference,ENUM_APPLIED_PRICE price,
                         ENUM_TIMEFRAMES stochTf,int k, int d, int s,
                         ENUM_TIMEFRAMES maTf,maswitch inpPeriod,int maPeriod,int fastMaPeriod,int slowMaPeriod,int cmoPeriod,ENUM_APPLIED_PRICE apPrice)
  {
//--- get handle for Stochastic indicator
   bbTrendHandle=iCustom(symbol,tf,"Market/BB Trend Flat MT5",label,bbPeriod,bbDeviation,bbFlat);
   atrHandle = iATR(symbol,tf,atrPeriod);
   kamaHandle = iCustom(symbol,tf,"kama-with-filter-indicator",kamaPeriod,fastEndPeriod,slowEndPeriod,smoothPower,filter,filterPeriod,filterDifference,price);
   mtfStochasticHandle = iCustom(symbol,tf,"Market/SC MTF Stochastic MT5",stochTf,0,k,d,s);
   maHandle =  iCustom(_Symbol,PERIOD_CURRENT,"iunima_mtf",maTf,inpPeriod,maPeriod,fastMaPeriod,slowMaPeriod,cmoPeriod, apPrice);
   //mtfStochasticHandle = iStochastic(symbol,tf,k,d,s,MODE_SMA,STO_LOWHIGH);
   
//--- get the handle for Moving Average of rsi indicator
   //maRsiHandle=iCustom(_Symbol,period,"MaRSi",period,rsiPeriod,maPeriod);
   //rsiHandle = iRSI(_Symbol,period,rsiPeriod,PRICE_OPEN);
//--- what if handle returns Invalid Handle
   if(bbTrendHandle<0)
     {
      errorMsg="Error Creating Handles for indicator bbTrend";
      errorCode=GetLastError();
      showError(errorMsg,errorCode);
     }
   if(atrHandle<0)
     {
      errorMsg="Error Creating Handles for indicators atr";
      errorCode=GetLastError();
      showError(errorMsg,errorCode);
     }
   if (kamaHandle<0)
      {
       errorMsg = "Error Creating handles for indicators kama";
       showError(errorMsg,errorCode);
      }
      
   if (mtfStochasticHandle<0)
      {
       errorMsg = "Error Creating handles for indicators mtf Stochastic";
       showError(errorMsg,errorCode);
      }
   if (maHandle<0)
      {
       errorMsg = "Error Creating handles for indicators mtf moving average";
       showError(errorMsg,errorCode);
      }
//--- set Arrays as series
//--- the ma and rsi values arrays
   //ArraySetAsSeries(rsi,true);
//--- the +DI value arrays
   //ArraySetAsSeries(maOfRsi,true);
   //ArraySetAsSeries(rsi2,true);
//--- the -DI value arrays
   //ArraySetAsSeries(mainStoch,true);
//--- the MA values arrays
   //ArraySetAsSeries(signalStoch,true);
   ArraySetAsSeries(bbTrend,true);
   ArraySetAsSeries(kama,true);
   ArraySetAsSeries(atr,true);
   ArraySetAsSeries(mtfStochMain,true);
   ArraySetAsSeries(mtfStochSig,true);
   ArraySetAsSeries(maBuffer,true);

  }
  
void GMexpert::doUnInit()
  {
//--- release our indicator handles
   IndicatorRelease(bbTrendHandle);
   IndicatorRelease(atrHandle);
   IndicatorRelease(kamaHandle);
   IndicatorRelease(mtfStochasticHandle);
   IndicatorRelease(maHandle);
   //IndicatorRelease(rsiHandle);
   //IndicatorRelease(stochasticHandle);
  }
  
  
void GMexpert::getBuffers()
  {
   
   
   if( CopyBuffer(bbTrendHandle,1,0,5,bbTrend)< 0)
     {
      errorMsg="Error copying indicator bb Trend Buffers";
      errorCode = GetLastError();
      showError(errorMsg,errorCode);
     }
   if(CopyBuffer(atrHandle,0,0,5,atr)<0)
   {
      errorMsg="Error copying indicator atr Buffers";
      errorCode = GetLastError();
      showError(errorMsg,errorCode);
   }
   if( CopyBuffer(kamaHandle,1,0,5,kama)<0)
     {
      errorMsg ="Error copying indicator Buffers for kama";
      errorCode = GetLastError();
      showError(errorMsg,errorCode);
     }
   if( CopyBuffer(mtfStochasticHandle,0,0,5,mtfStochMain)<0 || CopyBuffer(mtfStochasticHandle,1,0,5,mtfStochSig)<0)
     {
      errorMsg="Error copying indicator Buffers mtfStoch";
      errorCode = GetLastError();
      showError(errorMsg,errorCode);
     }
   if(CopyBuffer(maHandle,1,0,10,maBuffer)<0)
     {
      errorMsg="Error copying indicator Buffers mtf moving average";
      errorCode = GetLastError();
      showError(errorMsg,errorCode);
     }
  }
  
bool GMexpert::checkRange()
{
   getBuffers();
   bool Condition1 = false;
   
   Condition1 = bbTrend[1] == 2;
   
   return(Condition1);

}
bool GMexpert::checkBuy()
  {
/*
    Check for a Long/Buy Setup : check if rsi has crossed above ma and is still above it 
    and check if lower period stochastic has crossed 
*/ //Print("Does thsi even workk -------------------------------------------f dudlfdlfa");
   getBuffers();
   bool Buy_Condition_1 =false;
   bool Buy_Condition_2 = false;
   bool Buy_Condition_3 = false;
   //Print(prevMaOfRsi);
   //Print("Does this work upto here?-------------------------------------------------------->");
//--- declare bool type variables to hold our Buy Conditions
   Buy_Condition_1 =  maBuffer[1] == 1;
   Buy_Condition_2 = true;
   Buy_Condition_3 = true;
      
   
   
                     
//--- Putting all together   
   if(Buy_Condition_1 && Buy_Condition_2)
     {
      return(true);
     }
   else
     {
      return(false);
     }
  }
  

  
//+------------------------------------------------------------------+
//| CHECKSELL FUNCTION                                               |
//| *No input parameters                                             |
//| *Uses the class data members to check for Sell setup             |
//|  based on the defined trade strategy                             |
//| *Returns TRUE if Sell conditions are met or FALSE if not met     |
//+------------------------------------------------------------------+

bool GMexpert::checkSell()
  {
/*
    Check for a Short/Sell Setup : MA decreasing downwards, 
    previous price close below MA, ADX > ADX min, -DI > +DI
*/
   getBuffers();
   bool Sell_Condition_1 = false;
   bool Sell_Condition_2 = false;
   bool Sell_Condition_3 = false;
//--- declare bool type variables to hold our Sell Conditions
   
   
   Sell_Condition_1 = maBuffer[1] == 0;
   Sell_Condition_2 = true;
   Sell_Condition_3 = true;
   
                      
//--- Putting all together   
   if(Sell_Condition_1 && Sell_Condition_2)
     {
      return(true);
      Print("This is equal to true");
     }
   else
     {
      return(false);
     }
  }
  
  
bool GMexpert::checkIntBuy()
{
   getBuffers();
   bool buy_condition_1 = false;
   bool buy_condition_2 = false;
   
   buy_condition_1 = bbTrend[1] == 0;
   buy_condition_2 = (mtfStochMain[2]< mtfStochSig[2] && mtfStochMain[1] >= mtfStochSig[1]);
   
   if (buy_condition_1 && buy_condition_2)
   {
      return(true); 
   }
   else
   {
      return(false);
   }
}
bool GMexpert::checkIntBuyOpp()
{
   getBuffers();
   bool buy_condition_1 = false;
   bool buy_condition_2 = false;
   
   buy_condition_1 = bbTrend[1] == 0;
   buy_condition_2 = mtfStochMain[2] >= mtfStochSig[2] && mtfStochMain[1] <= mtfStochSig[1];
   
   if (buy_condition_1 && buy_condition_2)
   {
      return(true); 
   }
   else
   {
      return(false);
   }

}

bool GMexpert::checkIntSell()
{
   getBuffers();
   bool sell_condition_1 = false;
   bool sell_condition_2 = false;
   
   
   sell_condition_1 = bbTrend[1] == 1;
   sell_condition_2 = mtfStochMain[2]> mtfStochSig[2] && mtfStochMain[1] <= mtfStochSig[1];
   
   if (sell_condition_1 && sell_condition_2)
   {
      return(true);
   }else
   {
      return(false);
   }
}  

bool GMexpert::checkIntSellOpp()
{
   getBuffers();
   bool sell_condition_1 = false;
   bool sell_condition_2 = false;
   
   sell_condition_1 = bbTrend[1] == 1;
   sell_condition_2 = mtfStochMain[2] <= mtfStochSig[2] && mtfStochMain[1] >= mtfStochSig[1];
   
   if (sell_condition_1 && sell_condition_2)
   {
      return(true); 
   }
   else
   {
      return(false);
   }

}
bool GMexpert::checkPeriodEnd()
{

   getBuffers();
   bool sell_condition_1 = false;
   bool buy_condition_1 = false;
   bool prev_buy_condition_1 = false;
   bool prev_sell_condition_1 = false;
   
   prev_sell_condition_1 = bbTrend[2];
   prev_buy_condition_1 = bbTrend[2];
   sell_condition_1 = bbTrend[1];
   buy_condition_1 = bbTrend[1];
   
   //Dealing with ranging market scenerio
   if (prev_sell_condition_1 == 2)
   {  
      int i = 3;
      while(prev_sell_condition_1 ==2)
      {
         prev_sell_condition_1 = bbTrend[i];
         i++;
      }
   }
   if (prev_buy_condition_1 == 2)
   {  
      int i = 3;
      while(prev_buy_condition_1 ==2)
      {
         prev_buy_condition_1 = bbTrend[i];
         i++;
      }
   }
   // If it turns from red to green or green to red
   if ((prev_sell_condition_1 == 1 && buy_condition_1 ==0) || (prev_buy_condition_1 ==0 && sell_condition_1 == 1))
   {
      return(true);
   }
   // how to check if it turns from range to red from green
   else
   {
      return(false);
   }
  
}
//+------------------------------------------------------------------+
//| OPENBUY FUNCTION                                                 |
//| *Has Input parameters - order type, Current ASK price,           |
//|  Stop Loss, Take Profit, deviation, comment                      |
//| *Checks account free margin before pacing trade if trader chooses|
//| *Alerts of a success if position is opened or shows error        |
//+------------------------------------------------------------------+
void GMexpert::openBuy(ENUM_ORDER_TYPE otype,double askprice,double SL,double TP,int dev,string comment="")
  {
//--- do check Margin if enabled
   if(Chk_Margin==1)
     {
      if(MarginOK(lotSize)==false)
        {
         errorMsg= "You do not have enough money to open this Position!!!";
         errorCode =GetLastError();
         showError(errorMsg,errorCode);
        }
      else
        {
         trequest.action=TRADE_ACTION_DEAL;
         trequest.type=otype;
         trequest.volume=lotSize;
         trequest.price=askprice;
         trequest.sl=SL;
         trequest.tp=TP;
         trequest.deviation=dev;
         trequest.magic=magicNo;
         trequest.symbol=symbol;
         trequest.type_filling=ORDER_FILLING_FOK;
         trequest.comment= comment;
         //--- send
         OrderSend(trequest,tresult);
         //--- check result
         if(tresult.retcode==10009 || tresult.retcode==10008) //Request successfully completed 
           {
            Alert("A Buy order has been successfully placed with Ticket#:",tresult.order,"!!");
           }
         else
           {
            errorMsg= "The Buy order request could not be completed";
            errorCode =GetLastError();
            showError(errorMsg,errorCode);
           }
        }
     }
   else
     {
      trequest.action=TRADE_ACTION_DEAL;
      trequest.type=otype;
      trequest.volume=lotSize;
      trequest.price=askprice;
      trequest.sl=SL;
      trequest.tp=TP;
      trequest.deviation=dev;
      trequest.magic=magicNo;
      trequest.symbol=symbol;
      trequest.type_filling=ORDER_FILLING_FOK;
      trequest.comment = comment;
      //--- send
      OrderSend(trequest,tresult);
      //--- check result
      if(tresult.retcode==10009 || tresult.retcode==10008) //Request successfully completed 
        {
         Alert("A Buy order has been successfully placed with Ticket#:",tresult.order,"!!");
        }
      else
        {
         errorMsg= "The Buy order request could not be completed";
         errorCode =GetLastError();
         showError(errorMsg,errorCode);
        }
     }
  }

//+------------------------------------------------------------------+
//| OPENSELL FUNCTION                                                |
//| *Has Input parameters - order type, Current BID price, Stop Loss,|
//|  Take Profit, deviation, comment                                 |
//| *Checks account free margin before pacing trade if trader chooses|
//| *Alerts of a success if position is opened or shows error        |
//+------------------------------------------------------------------+
void GMexpert::openSell(ENUM_ORDER_TYPE otype,double bidprice,double SL,double TP,int dev,string comment="")
  {
//--- do check Margin if enabled
   if(Chk_Margin==1)
     {
      if(MarginOK(lotSize)==false)
        {
         errorMsg= "You do not have enough money to open this Position!!!";
         errorCode =GetLastError();
         showError(errorMsg,errorCode);
        }
      else
        {
         trequest.action=TRADE_ACTION_DEAL;
         trequest.type=otype;
         trequest.volume=lotSize;
         trequest.price=bidprice;
         trequest.sl=SL;
         trequest.tp=TP;
         trequest.deviation=dev;
         trequest.magic=magicNo;
         trequest.symbol=symbol;
         trequest.type_filling=ORDER_FILLING_FOK;
         trequest.comment = comment;
         //--- send
         OrderSend(trequest,tresult);
         //--- check result
         if(tresult.retcode==10009 || tresult.retcode==10008) //Request successfully completed 
           {
            Alert("A Sell order has been successfully placed with Ticket#:",tresult.order,"!!");
           }
         else
           {
            errorMsg= "The Sell order request could not be completed";
            errorCode =GetLastError();
            showError(errorMsg,errorCode);
           }
        }
     }
   else
     {
      trequest.action=TRADE_ACTION_DEAL;
      trequest.type=otype;
      trequest.volume=lotSize;
      trequest.price=bidprice;
      trequest.sl=SL;
      trequest.tp=TP;
      trequest.deviation=dev;
      trequest.magic=magicNo;
      trequest.symbol=symbol;
      trequest.type_filling=ORDER_FILLING_FOK;
      trequest.comment = comment;
      //--- send
      OrderSend(trequest,tresult);
      //--- check result
      if(tresult.retcode==10009 || tresult.retcode==10008) //Request successfully completed 
        {
         Alert("A Sell order has been successfully placed with Ticket#:",tresult.order,"!!");
        }
      else
        {
         errorMsg= "The Sell order request could not be completed";
         errorCode =GetLastError();
         showError(errorMsg,errorCode);
        }
     }
  }
  
//+----------------------------------------------------------------+
double GMexpert::openPositionsProfitLoss()
{
   int returns = 0;
   int profit = 0;
   int loss = 0;
   double result;
   ulong ticket;
   
   for(int i = 0; i< PositionsTotal();i++)
   {
      if(ticket = PositionGetTicket(i)>0)
      {
         result = PositionGetDouble(POSITION_PROFIT);
         if(result > 0)profit+=result;
         if(result < 0) loss+=result;
      }
      
      
   }
   
   returns = profit + loss;
   return returns;
}

double GMexpert::lastPositionGridLoss(int prevTrades)
{
   // --- determine the time intervals of the required trading history
   datetime end=TimeCurrent();                 // current server time
   datetime start=end-PeriodSeconds(PERIOD_D1);// set the beginning time to 24 hours ago

//--- request in the cache of the program the needed interval of the trading history
   HistorySelect(start,end);
//--- obtain the number of deals in the history
   int deals=HistoryDealsTotal();
   //ulong first_deal,last_deal,deals=HistoryOrdersTotal();

   int returns=0;
   double profit=0;
   double loss=0;
   double result;
  
   
//--- scan through all of the deals in the history
   for(int i = 0; i<prevTrades; i++)
     {
      //--- obtain the ticket of the deals by its index in the list
      Print("----------------------This is inside the trade acajdk;53432544-------------------------------------------");
      ulong deal_ticket=HistoryDealGetTicket(((deals-1)-i));
      if(deal_ticket>0) // obtain into the cache the deal, and work with it
        {
         string symbol             =HistoryDealGetString(deal_ticket,DEAL_SYMBOL);
         datetime time             =HistoryDealGetInteger(deal_ticket,DEAL_TIME);
         ulong order               =HistoryDealGetInteger(deal_ticket,DEAL_ORDER);
         long order_magic          =HistoryDealGetInteger(deal_ticket,DEAL_MAGIC);
         long pos_ID               =HistoryDealGetInteger(deal_ticket,DEAL_POSITION_ID);
         ENUM_DEAL_ENTRY entry_type=HistoryDealGetInteger(deal_ticket,DEAL_ENTRY);
         Print("$%$%$#%$%$%$%$#@%$#%@#$%@#$%@#$%@#$%@#4 History deals innit $%^$@#$#@$@#$@#$@#%@#$%234");
         Print(entry_type);
         Print(DEAL_ENTRY_OUT);
         
         Print("This is Entry type : ", entry_type,"Thsis is deal entry out : ", DEAL_ENTRY_OUT);

         //--- process the deals with the indicated DEAL_MAGIC
         if(order_magic==magicNo)
           {
            //... necessary actions
           }

         //--- calculate the losses and profits with a fixed results
         if(entry_type==DEAL_ENTRY_OUT)
        
          {
          Print("$%$%$#%$%$%$%$#@%$#%@#$%@#$%@#$%@#$%@#4 History deal entry out innit $%^$@#$#@$@#$@#$@#%@#$%234");
          
            //--- increase the number of deals 
            returns++;
            //--- result of fixation
            result=HistoryDealGetDouble(deal_ticket,DEAL_PROFIT);
            //--- input the positive results into the summarized profit
            Print("This is result for deal i: ",i, " Profit ==", result);
            if(result>0) profit+=result;
            //--- input the negative results into the summarized losses
            if(result<0) loss+=result;
           }
        }
      else // unsuccessful attempt to obtain a deal
        {
         PrintFormat("We couldn't select a deal, with the index %d. Error %d",
                     i,GetLastError());
        }
     }
   //--- output the results of the calculations
   PrintFormat("The total number of %d deals with a financial result. Profit=%.2f , Loss= %.2f",
               returns,profit,loss);
               
   Print("These are the number of open trades pulled from history", prevTrades);
               
               
    if(result > 0){return profit;}
    else{return loss;}
}
bool GMexpert::checkCloseCondition()
{
   getBuffers();
   //Print("This is kama[2]  ",kama[2]," This is kama [1]  ", kama[1]);
   if (((kama[2] != 1) &&(kama[1] ==1)) ||((kama[2] !=2) && (kama[1] == 2 )))
   {
      return true;
   }
   else
   {
      return false;
   }
};


void GMexpert::setLotMultiplier(double returns)
{

   //double returns = lastPositionGridLoss();
   if (returns < 0 )
   {  getBuffers();
      returns = MathAbs(returns); // get absolute value of the loss to use for calculations
      double atrVal = atr[1];
      if (_Digits == 5)
      {
         atrVal = NormalizeDouble(atrVal ,1);
      }
      else
      {
         atrVal = NormalizeDouble(atrVal,1);
      }
      
      
      double vol = (returns + atrVal/10)/atrVal/10; 
      Print("This is returns lol --------------------->", returns,"This is atrVal", atrVal, "This is the volume size ; ", vol );
      setLotsizeMg(vol);   
   }
   else setLotsizeMg(0.0);
}

int GMexpert::calculateSl()
{
      getBuffers();
      double atrVal = atr[1];
      if (_Digits == 5)
      {
         atrVal = NormalizeDouble(atrVal * 100000,1);
      }
      else
      {
         atrVal = NormalizeDouble(atrVal * 1000,1);
      }
      
      int sl = NormalizeDouble(atrVal * 2.0,0) ;
      
      return sl;

}


int GMexpert::calculateTp()
{
      getBuffers();
      double atrVal = atr[1];
      if (_Digits == 5)
      {
         atrVal = NormalizeDouble(atrVal * 100000,1);
      }
      else
      {
         atrVal = NormalizeDouble(atrVal * 1000,1);
      }
      
      double tp = NormalizeDouble(atrVal * 2.5,0) ;
      
      return tp;

}

int GMexpert::atrValue()
{
   getBuffers();
   int atrVals = NormalizeDouble(atr[1],1);
   
   return atrVals;
}

string GMexpert::previousOrderType()
{
   getBuffers();
   
   if(bbTrend[2] == 0)
   {
      return "buy";
   }
   else if(bbTrend[2] ==1)
   {
      return "Sell";
   }
   
   else
   {
      return "ranging";
   }
}

bool GMexpert::checkBuyExit()
{
   getBuffers();
   
   bool sellCondition = false;
   
   sellCondition = (maBuffer[2] == 1 && maBuffer[1] == 0);
   
   //Print("----------------------------------------------------------------------------------------------------");
   //Print("--------------> this is mabuffer prev[] ", maBuffer[1],"-------------> this is second  : ",maBuffer[0] );
   
   if (sellCondition) return(true);
   else return(false);

}