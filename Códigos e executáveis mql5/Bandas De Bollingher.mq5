//+------------------------------------------------------------------+
//|                                         Bandas de Bollingher.mq5 |
//|                                                  William Brandão |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "William Brandão"
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
input string Ativo_trade = "SMAL11";         // Ativo de negociação
input int Periodo = 20;     //PERIODO
input double Desvio = 2;       //DESVIO
//input string Ativo_1 = "GBPUSD";           // Ativo 1
//input string Ativo_2 = "EURUSD";           // Ativo 2

//input group "PARÂMETROS DA LÓGICA OPERACIONAL"
//input double Var_atv_1 = 1;                // Parâmetro 1
//input double Var_atv_2 = 1;                // Parâmetro 2

input group "GERENCIAMENTO DE POSIÇÃO"
input int TP = 200;                          // Take Profit (Em Ticks)
input int SL = 200;                          // Stop Loss (Em Ticks)
input int TS = 50;                           // Passo Trailing Stop (Em ticks) somente se trailing stop ativado
input int SP = 20;                           // Filtro de Spread (validar entrada somente se spread menor que...) (Em ticks)
input double lot = 1;                        // Tamanho do lote

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
string entry = "";

MqlRates PriceInfo[];
ArraySetAsSeries(PriceInfo,true);

int PriceData = CopyRates(Symbol(),PERIOD_CURRENT,0,3,PriceInfo);

double Bandacima[];
ArraySetAsSeries(Bandacima,true);

double Bandabaixo[];
ArraySetAsSeries(Bandabaixo,true);

int BBDefinition = iBands(_Symbol,PERIOD_CURRENT,Periodo,0,Desvio,PRICE_CLOSE);

CopyBuffer(BBDefinition,1,0,3,Bandacima);
CopyBuffer(BBDefinition,2,0,3,Bandabaixo);

double mybandacimaValue = Bandacima[0];
double mybandabaixoValue = Bandabaixo[0];

double myLastbandacimaValue = Bandacima[1];
double myLastbandabaixoValue = Bandabaixo[1];


if((PriceInfo[0].close>mybandabaixoValue) && (PriceInfo[1].close<myLastbandabaixoValue))
  {
   entry = "venda";
  }

if((PriceInfo[0].close<mybandacimaValue) && (PriceInfo[1].close>myLastbandacimaValue))
  {
   entry = "compra";
  }

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

if(!comprado && !vendido && spread<=SP && HoraCorrente>=HoraInicial && HoraCorrente<HoraFinal)
  {
   if(direction == Comprado && entry == "compra")
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
     if(direction == Vendido && entry == "venda")
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


/*

# Bollinger Bands Trading Bot for MetaTrader 5

**Autor:** William Brandão  
**Linguagem:** MQL5  
**Categoria:** Trading System (Expert Advisor)  
**Plataforma:** MetaTrader 5  
**Versão:** 1.0

## 📌 Descrição

Este projeto implementa um Expert Advisor (EA) baseado em Bandas de Bollinger para o MetaTrader 5. Ele permite:

- Execução automática de ordens de compra e venda com base na lógica das Bandas de Bollinger
- Uso em contas demo e reais (.ex5 compilado incluído)
- Parametrização de TP, SL, trailing stop, horário de operação e filtros de spread
- Backtests automatizados com relatórios de performance
- Encerramento por horário, lógica reversa ou sinal validado
- Totalmente compatível com operações manuais ou automáticas

## ⚙️ Funcionalidades

- 📈 **Análise técnica:** Bandas de Bollinger com desvio e período customizáveis
- 🕒 **Gerenciamento de tempo:** Entrada e saída por horários definidos
- 💰 **Gerenciamento de risco:** TP, SL, trailing stop e spread mínimo
- 📊 **Backtests:** Com relatórios de desempenho (.pdf) e curvas de capital

## 🧪 Requisitos

- MetaTrader 5 instalado
- Conta demo ou real (qualquer corretora MT5)
- Permissão de AutoTrading habilitada

## 🚀 Como usar

### 1. Instalar o Bot
- Copie o arquivo `BollingerBot.ex5` da pasta `bin/` para:  
  `MQL5/Experts/` dentro do diretório de dados do seu MT5

### 2. Compilar a versão de desenvolvimento (opcional)
- Use o MetaEditor para abrir `src/BollingerBot.mq5`
- Compile pressionando **F7** para gerar o `.ex5`

### 3. Executar no MT5
- Abra o MetaTrader 5
- Adicione o bot ao gráfico do ativo desejado (ex: `SMAL11`)
- Configure os inputs conforme desejado

### 4. Backtest
- Vá para “Testador de Estratégia”
- Selecione o ativo e período
- Marque “Visualizar” e execute o teste
- Os resultados estarão na pasta `backtests/`

## 📄 Documentação

- [`docs/architecture.md`](docs/architecture.md): Arquitetura do bot
- [`docs/user_guide.md`](docs/user_guide.md): Guia completo de uso
- [`docs/changelog.md`](docs/changelog.md): Histórico de versões

## 📈 Exemplos de Performance

![Equity Curve](backtests/equity_curve.png)

Relatório detalhado: [`performance_report.pdf`](backtests/performance_report.pdf)

## 🔐 Licença

Este projeto está licenciado sob a [MIT License](LICENSE).

---

**Contato:** william.brandao.ds@gmail.com  
**LinkedIn:** [Seu perfil aqui]

*/