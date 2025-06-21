# Projeto: Comparativo de Estratégias Quantitativas vs Buy and Hold


🧠 Visão Geral

Este projeto tem como objetivo desenvolver, testar e comparar um conjunto de estratégias técnicas de trading (ensemble) com o modelo tradicional de Buy and Hold. A proposta é avaliar o desempenho, risco e robustez de cada abordagem no contexto de mercado brasileiro, utilizando ferramentas de modelagem quantitativa e automação em MQL5.

🎯 Objetivos

Desenvolver um ensemble de estratégias técnicas baseado em indicadores clássicos.

Otimizar os parâmetros de cada estratégia com a técnica Walk-Forward Analysis (WFA).

Comparar a performance acumulada frente ao modelo Buy and Hold.

Analisar o impacto de controle de risco, como stop loss, trailing stop, filtro de spread e horário de fechamento.

🛠️ Tecnologias Utilizadas

MQL5 para desenvolvimento dos indicadores e experts advisors (EAs)

Python para análise gráfica e comparação estatística

Plotly para visualização interativa

Walk-Forward Analysis (WFA) como técnica de validação fora da amostra

📈 Indicadores Técnicos Utilizados

Bandas de Bollinger

MACD

Estocástico

IFR (Índice de Força Relativa)

Cada um dos indicadores foi configurado em estratégias singulares e posteriormente combinados para formar um ensemble robusto com controle estatístico de risco.

⚙️ Funcionalidades dos EAs

Operações de compra e venda (long/short)

Encerramento automático por horário

Stop Loss e Take Profit configuráveis

Trailing Stop dinâmico

Filtro de spread para evitar operações ineficientes

📊 Resultados

O gráfico a seguir demonstra o resultado acumulado da estratégia comparada ao modelo Buy and Hold:


Principais observações:

Descolamento do risco de mercado (baixa correlação)

Menor volatilidade com ganhos consistentes

Melhor controle de drawdown em períodos de stress de mercado

🔬 Metodologia de Otimização: Walk-Forward Analysis

A técnica WFA consiste em dividir o histórico de dados em múltiplos blocos de treinamento e teste, permitindo:

Redução de overfitting

Acompanhamento da robustez da estratégia ao longo do tempo

Aplicabilidade prática em produção

📂 Estrutura do Projeto

├── indicadores_mql5/
│   ├── bollinger.mq5
│   ├── macd.mq5
│   └── estocastico_ifr.mq5
├── experts/
│   ├── estrategia_ensemble.mq5
├── relatorios/
│   └── comparativo_plotly.html
├── imagens/
│   ├── resultado_estrategia.png
│   └── capa_projeto.png
└── README.md

👨‍💼 Sobre o Autor

William BrandãoCientista de Dados com foco em Finanças Quantitativas 💹🎓 Economia & Ciências Contábeis🔬 Especialista em modelagem preditiva e automação de estratégias de investimento📍 Sorocaba - SP, Brasil📫 williambrandao@outlook.com

📢 Contato

Fique à vontade para entrar em contato para dúvidas, colaborações ou sugestões. Este projeto está aberto para expansão e integração com novas técnicas quantitativas.

"Transformar dados em decisões inteligentes é o futuro das finanças quantitativas.
