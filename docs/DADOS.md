# Dados e fontes

## Preços

Vêm do scanner próprio (`Scanner.lua`), sem outros addons.

- **Scan completo**: `C_AuctionHouse.ReplicateItems`, permitido pelo jogo uma vez a cada 15 minutos. Os leilões são lidos em blocos de 500 por quadro para não travar o jogo.
- **Busca rápida**: `C_AuctionHouse.SendSearchQuery`, um item por vez. Traz o número de cada leilão, necessário para comprar.
- **Por item** (`GarimpoDB.market`): menor preço por unidade, valor de mercado (média dos 15% mais baratos da quantidade à venda, sem contar os seus leilões), quantidade à venda e hora do scan.
- **Histórico** (`GarimpoDB.prices`): um valor de mercado por dia, por 35 dias. Tendências, sugestões e ofertas usam a média dos 7 dias anteriores.
- **Ofertas**: leilões até o preço máximo *média de 7 dias × (1 − taxa do Leilão) ÷ (1 + spread)*, com lucro de revenda (mercado × (1 − taxa) − preço pago) acima do lucro mínimo. Os leilões do último scan ficam só na memória; depois de um `/reload` é preciso escanear de novo para ver ofertas.
- **Vendedores**: preço real de venda tirado do Wowhead (`Data/Vendors.lua`). Para itens sem esse dado, a estimativa é 4 vezes o valor que o vendedor paga.

## Gold por hora

- **Estimado**: `Data/Items.lua` define, para cada categoria, faixas de farm com zonas e uma quantidade típica de cada item por hora. Esses números são estimativas aproximadas.
- **Medido**: cada item saqueado (minério, erva, peixe, couro, tecido, encantamento, transmog) soma o preço atual ao total da categoria. Saques com menos de 5 minutos de intervalo contam como tempo contínuo de farm.

## Rotas de profissão

`Data/Professions.lua`.

| Profissão | Fonte |
|---|---|
| Ferraria, Alfaiataria, Encantamento, Primeiros Socorros, Culinária, Pesca | Guias do [wow-professions.com](https://www.wow-professions.com/forever) para o Forever, até o 225. Acima de 225 o próprio guia está marcado como não testado. |
| Mineração, Herborismo, Esfolamento | Faixas padrão do Classic; o site não tem guia do Forever para elas. |
| Alquimia, Engenharia, Couraria | Ainda sem rota; o Garimpo mostra o link do guia. |

Os nomes das receitas em português são traduções. Reagentes, itens e zonas vêm traduzidos pelo próprio jogo.

## Vendedores

`Data/Vendors.lua`, gerado por `tools/vendors.py` a partir das páginas de itens do Wowhead Classic:

- lista "Vendido por" de cada item: vendedor, zona, facção e preço;
- mapa de vendedores da página: coordenadas por zona;
- em zonas com vendedores das duas facções, a página de cada vendedor, para ter a posição e a facção exatas.

Cobre os itens de vendedor usados nas rotas: fundentes, linhas, tinturas, temperos, frascos, sementes, carvão e varas.

## Nós de minério e erva

`Data/Nodes.lua`, gerado por `tools/nodes.py`:

- para cada minério e erva, os objetos de onde ele sai (veios, plantas) na página do item;
- os pontos de nascimento de cada objeto, por zona;
- por zona: a área com mais nós (calculada no script), o total de nós e no máximo 40 pontos para desenhar no mapa.

Peixes não têm pontos de cardume no Wowhead Classic; para eles e para tecido, couro e carnes, valem os pontos que o Garimpo grava quando você coleta (`GarimpoDB.nodes`).

## Gerar os dados de novo

Precisa de Python 3. Os scripts ficam em `tools/` e guardam as páginas baixadas numa pasta de cache, então rodar de novo não baixa tudo outra vez.

```
python tools/vendors.py <pasta-cache> Data/Vendors.lua
python tools/nodes.py   <pasta-cache> Data/Nodes.lua
```

Os scripts esperam 3 segundos entre cada página para não sobrecarregar o Wowhead. A coleta completa leva cerca de 15 minutos.

## Mídia

| Arquivo | Origem |
|---|---|
| `Media/Arrow.tga` | Gerado por `tools/make_arrow.py`. |
| `Media/CashRegister.mp3` | Fornecido pelo autor do addon. Confirme a licença antes de redistribuir. |
