//+------------------------------------------------------------------+
//|                                                |
//|                             |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Mercado Financeiro Automatizado (MFA)"
#property link      ""
#property version   "1.00"

#include <Math\Stat\Normal.mqh>
#include  <Math/Stat/Math.mqh>
#include<Trade/Trade.mqh>

CTrade trade;

enum trade_direction
  {
   Comprado,                                 // [1] Comprado
   Vendido                                   // [2] Vendido
  };
  
enum use_trailing_stop
  {
   Nao,                                      // [1] Não
   Sim                                       // [2] Sim
  };
  
enum use_time_close
  {
   Nao_time,                                 // [1] Não
   Sim_time                                  // [2] Sim
  };
  
enum use_tp_sl
  {
   Nao_tp_sl,                                // [1] Não
   Sim_tp_sl                                 // [2] Sim
  };
  
  enum ENUM_CALC_MODE
  
     {
   PRICE_CLOSEs  ,         // [1] FECHAMENTO
   PRICE_OPENs    ,        // [2] ABERTURA
   PRICE_MEDIANS           // [3] MEDIANO (máximo + mínimo)/2     
     };  
     
enum indicador
  {
   bb,                                       // [1] Bandas de Bollingher
   macd                                      // [2] MACD
  };     

// input group "INDICADOR"
// input indicador indicator = bb;              // Indicador

input group "PERMISSÕES E CONCESSÕES"
//input int TT = 1;                          // Quantidade máxima de trades permitido por dia
input use_time_close time_close = Sim_time;  // Fechar posições por horário?
input use_tp_sl tp_sl = Sim_tp_sl;           // Usar Take Proft e Stop Loss?
input use_trailing_stop trailing_stop = Nao; // Usar Trailing stop?
input trade_direction direction = Comprado;  // Direção do trade
input ulong MagicNumber = 1;                 // Magic Number

input group "HORÁRIO DE NEGOCIAÇÃO"
input string HoraInicial = "00:30";          // Hora Inicial
input string HoraFinal = "23:30";            // Hora Final (Fechará todas as posições)
//input string HoraFinal2 = "23:30";         // Hora Final DIA SEGUINTE (Fechará todas as posições)

input group "ATIVOS DA LÓGICA OPERACIONAL"
input string Ativo_trade = "GBPUSD";         // Ativo de negociação


input group "MACD"
input int MA_CURTA = 5;                      //Média curta
input int MA_LONGA = 15;                     //Média longa
input int PeriodoSinal = 9;                  //Periodo sinal
//input ENUM_CALC_MODE CalcMode = PRICE_CLOSEs;  // APLICAR SINAL A

//input group "PARÂMETROS DA LÓGICA OPERACIONAL"
//input double Var_atv_1 = 1;                // Parâmetro 1
//input double Var_atv_2 = 1;                // Parâmetro 2

input group "GERENCIAMENTO DE POSIÇÃO"
input int TP = 200;                          // Take Profit (Em Ticks)
input int SL = 200;                          // Stop Loss (Em Ticks)
input int TS = 50;                           // Passo Trailing Stop (Em ticks) somente se trailing stop ativado
input int SP = 20;                           // Filtro de Spread (validar entrada somente se spread menor que...) (Em ticks)
input double lot = 0.01;                     // Tamanho do lote

//--- Variáveis global
string HoraCorrente;
string HoraCorrente_dia_seguinte;
bool TradingIsAllowed = false;

bool h_permitida = false;

int barsToCopy = 6;
MqlRates gbpusd[];
MqlRates eurusd[];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
trade.SetExpertMagicNumber(MagicNumber);

//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
datetime Time = TimeLocal();
datetime Time_amanha = TimeLocal() + 86400;

HoraCorrente = TimeToString(Time,TIME_MINUTES);  
HoraCorrente_dia_seguinte = TimeToString(Time_amanha,TIME_MINUTES);  

   //--- Captura de dados -----------------------------------------------------------------------------------------------------

// Preço Ask
double Ask = NormalizeDouble(SymbolInfoDouble(Ativo_trade,SYMBOL_ASK),_Digits);
// Preço Bid
double Bid = NormalizeDouble(SymbolInfoDouble(Ativo_trade,SYMBOL_BID),_Digits);
// Valor Spread   
int spread = SymbolInfoInteger(Ativo_trade, SYMBOL_SPREAD);

ArraySetAsSeries(gbpusd,true);
//ArraySetAsSeries(eurusd,true);

double ativo1 = CopyRates(Ativo_trade, PERIOD_CURRENT, 1, barsToCopy, gbpusd);
//double ativo2 = CopyRates(Ativo_2, PERIOD_CURRENT, 1, barsToCopy, eurusd);

double atv1[];
ArrayResize(atv1, ArraySize(gbpusd));
//---

//--- Lógica operacional ----------------------------------------------------------------------------------------------------


//--- MACD ------------------------------------------------------------------------------------------------------------------
// Criador do sinal
string sinal = "";

// Matriz para os dados de preço
double myMACDArray[];

// Inversão do Array(Matriz)
ArraySetAsSeries(myMACDArray,true);

// Propriedades MACD
int myMACDDefinition = iMACD(_Symbol,PERIOD_CURRENT,MA_CURTA,MA_LONGA,PeriodoSinal,PRICE_CLOSE);

if(myMACDDefinition)
  {
   ChartIndicatorAdd(0,1,myMACDDefinition);
  }

//Definição do candle corrente para a matriz
CopyBuffer(myMACDDefinition,0,0,3,myMACDArray);

// Calcular o RSI corrente
float myMACDValue = (myMACDArray[0]);
float LastmyMACDValue = (myMACDArray[1]);

double MACDSINALcompra = (myMACDValue>0 && LastmyMACDValue<0);
if(MACDSINALcompra)
sinal = "venda";

double MACDSINALvenda = (myMACDValue<0 && LastmyMACDValue>0);
if(MACDSINALvenda)
sinal = "compra";

double INDICADORMACD = MACDSINALcompra || MACDSINALvenda; 


//--- Loop nas posições -----------------------------------------------------------------------------------------------------
   bool comprado = false;
   bool vendido  = false;
   ulong ticketComprado = 0;
   ulong ticketVendido = 0;
    
   // Caso não tenha posição, compre a marcado
   int positionsTotal = PositionsTotal();
   for(int i=0;i<positionsTotal;i++)
     {
      ulong posTicket = PositionGetTicket(i);
      if(PositionSelectByTicket(posTicket))
        {
         ulong posMagic = PositionGetInteger(POSITION_MAGIC);
         string posSymbol = PositionGetString(POSITION_SYMBOL);
         ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         
         // Já tenho posição com esse Magic Number
         if(posSymbol==Ativo_trade && posMagic==MagicNumber)
           {
            if(posType==POSITION_TYPE_BUY)
               {
                comprado = true;
                ticketComprado = posTicket;
               }
            
            if(posType==POSITION_TYPE_SELL) 
               {
                vendido = true;
                ticketVendido = posTicket;
               }
           }
        }
     }

//--- Abertura de posições -----------------------------------------------------------------------------------------------------

if((!comprado && !vendido) && spread<=SP && HoraCorrente>=HoraInicial && HoraCorrente<HoraFinal && (sinal == "venda" || sinal == "compra"))
  {
   if(direction == Comprado)
     {
      if(tp_sl==Sim_tp_sl)
        {
         trade.Buy(lot, Ativo_trade, 0, (Ask-(SL*_Point)), (Ask+(TP*_Point)), "Compra a mercado");
        }
        else
          {
           trade.Buy(lot, Ativo_trade, 0, 0, 0, "Compra a mercado");
          }
     }
     if(direction == Vendido)
       {
        if(tp_sl==Sim_tp_sl)
          {
           trade.Sell(lot, Ativo_trade, 0, (Bid+(SL*_Point)), ((Bid-TP*_Point)), "Venda a mercado");
          }
          else
            {
             trade.Sell(lot, Ativo_trade, 0, 0, 0, "Venda a mercado");
            }
       }
  }
  
if(isNewMinute() && tp_sl==Sim_tp_sl && trailing_stop == Sim)
 {
  if(comprado)
    {
     CheckTS(Ask);
    }
    else
      {
       CheckTSV(Bid);
      }
 }
   
  //}

if(time_close == Sim_time && HoraCorrente>=HoraFinal)
  {
  
  //--- Loop nas posições -----------------------------------------------------------------------------------------------------
   bool comprado = false;
   bool vendido  = false;
   ulong ticketComprado = 0;
   ulong ticketVendido = 0;
    
   // Caso não tenha posição, compre a marcado
   int positionsTotal = PositionsTotal();
   for(int i=0;i<positionsTotal;i++)
     {
      ulong posTicket = PositionGetTicket(i);
      if(PositionSelectByTicket(posTicket))
        {
         ulong posMagic = PositionGetInteger(POSITION_MAGIC);
         string posSymbol = PositionGetString(POSITION_SYMBOL);
         ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         
         // Já tenho posição com esse Magic Number
         if(posSymbol==Ativo_trade && posMagic==MagicNumber)
           {
            if(posType==POSITION_TYPE_BUY)
               {
                comprado = true;
                ticketComprado = posTicket;
               }
            
            if(posType==POSITION_TYPE_SELL) 
               {
                vendido = true;
                ticketVendido = posTicket;
               }
           }
        }
     }
  
   if(comprado)
     {
      trade.PositionClose(ticketComprado);
     }
     else
       {
        trade.PositionClose(ticketVendido);
       }
  }
   
  } // END ON TICK
//+------------------------------------------------------------------+

//--- New Minute
//+------------------------------------------------------------------+
bool isNewMinute()
  {
   static datetime last_time=0;
   datetime lastbar_time=(datetime)SeriesInfoInteger(Ativo_trade,PERIOD_M5,SERIES_LASTBAR_DATE);
   if(last_time==0)
     {
      last_time=lastbar_time;
      return(false);
     }
   if(last_time!=lastbar_time)
     {
      last_time=lastbar_time;
      return(true);
     }
   return(false);
} // END ISNEWMINUTE

//--- Trailing Stop Buy
//+------------------------------------------------------------------+
void CheckTS(double Ask)
{
double StopLoss = NormalizeDouble(Ask-SL*_Point,_Digits);
double TakeProfit = NormalizeDouble(Ask+TP*_Point,_Digits);

for(int i=PositionsTotal()-1; i>=0; i--)
{
  //string symbol = PositionGetSymbol(i);
  ulong posTicket = PositionGetTicket(i);
  ulong posMagic = PositionGetInteger(POSITION_MAGIC);
  string posSymbol = PositionGetString(POSITION_SYMBOL);

if(posSymbol==Ativo_trade && posMagic==MagicNumber)
  {
    ulong PositionTicket = PositionGetInteger(POSITION_TICKET); 
    
    double CurrentTS = PositionGetDouble(POSITION_SL);
    double CurrentTP = PositionGetDouble(POSITION_TP);
    
    if(CurrentTS < StopLoss /*&& CurrentTS > TakeProfit*/)
      {
       trade.PositionModify(posTicket,(CurrentTS+TS*_Point),(CurrentTP-0*_Point));  //((Ask+TP)-(CurrentTS+TS)*_Point)
      }          
  }
 }
} // END TRAILING STOP BUY

//--- Trailing Stop Sell
//+------------------------------------------------------------------+
void CheckTSV(double Bid)
{
double StopLoss_v = NormalizeDouble(Bid+SL*_Point,_Digits);

for(int i=PositionsTotal()-1; i>=0; i--)
{
  //string symbol = PositionGetSymbol(i);
  ulong posTicket = PositionGetTicket(i);
  ulong posMagic = PositionGetInteger(POSITION_MAGIC);
  string posSymbol = PositionGetString(POSITION_SYMBOL);

if(posSymbol==Ativo_trade && posMagic==MagicNumber)
  {
    ulong PositionTicket = PositionGetInteger(POSITION_TICKET); 
    
    double CurrentTS_v = PositionGetDouble(POSITION_SL);
    double CurrentTP_v = PositionGetDouble(POSITION_TP);
    
    if(CurrentTS_v>StopLoss_v)
      {
       trade.PositionModify(posTicket,(CurrentTS_v-TS*_Point),(CurrentTP_v-0*_Point));
      }
  }
 }
} // END TRAILING STOP SELL