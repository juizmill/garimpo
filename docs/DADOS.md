# Dados e fontes

## Preços

Vêm do scanner próprio (`Scanner.lua`), sem outros addons.

- **Scan completo**, de um de dois jeitos:
  - *Lista de leilões* (`C_AuctionHouse.ReplicateItems`): lê cada leilão, permitido pelo jogo uma vez a cada 15 minutos. Os leilões são lidos em blocos de 500 por quadro para não travar o jogo.
  - *Navegação* (`C_AuctionHouse.SendBrowseQuery` com busca em branco): uma linha por item à venda, com o menor preço e a quantidade total. Usado quando a lista de leilões não existe no cliente ou volta vazia; nesse caso o Garimpo lembra a escolha por um dia e não tem limite de 15 minutos. Como não traz cada leilão, o valor de mercado vira o menor preço até uma busca rápida detalhar o item.
- **Busca por item**: `C_AuctionHouse.SendSearchQuery`, um item por vez. Traz cada leilão com o número dele, necessário para comprar. Usada em três lugares: **Conferir ofertas** (itens da lista de ofertas), **Atualizar** do Ranking (itens acompanhados: categorias, reagentes das rotas, bolsas e banco) e **Buscar no Leilão** da aba Profissão do painel do Leilão (lista de compras).
- **Por item** (`GarimpoDB.market`): menor preço por unidade, valor de mercado (média dos 15% mais baratos da quantidade à venda, sem contar os seus leilões), quantidade à venda e hora do scan.
- **Histórico** (`GarimpoDB.prices`): um valor de mercado por dia, por 35 dias. Tendências, sugestões e ofertas usam a média dos 7 dias anteriores; para as ofertas, um dia anterior já basta.
- **Ofertas**: as 50 melhores compras que o seu gold paga (no máximo 3 por item). Primeiro as dentro da margem, ou seja, até o preço máximo *média de 7 dias × (1 − taxa do Leilão) ÷ (1 + spread)* e com lucro de revenda (mercado × (1 − taxa) − preço pago) acima do lucro mínimo, ordenadas pelo lucro. Depois, se faltar, as com retorno positivo abaixo da margem, ordenadas pelo retorno. A lista é refeita quando o seu gold muda. Os leilões do último scan ficam na memória; depois de um `/reload` ou relog, se o scan tiver até 30 minutos, as ofertas são refeitas a partir do menor preço salvo de cada item (`GarimpoDB.market`).
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

## Treinadores e NPCs das rotas

`Data/Trainers.lua`, gerado por `tools/trainers.py`:

- lista de treinadores de cada profissão na página da perícia no Wowhead Classic, com a posição de cada um;
- os NPCs citados nas etapas das rotas (treinadores especialistas, vendedores de livro, NPCs de missão), procurados pelo nome.

A Annora (Encantamento Artífice) fica dentro de Uldaman e não tem posição no Wowhead; a seta aponta para a zona.

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
python tools/trainers.py <pasta-cache> Data/Professions.lua Data/Trainers.lua
```

Os scripts esperam 3 segundos entre cada página para não sobrecarregar o Wowhead. A coleta completa leva cerca de 15 minutos.

## Mídia

| Arquivo | Origem |
|---|---|
| `Media/Arrow.tga` | Gerado por `tools/make_arrow.py`. |
| `Media/CashRegister.mp3` | Fornecido pelo autor do addon. Confirme a licença antes de redistribuir. |
