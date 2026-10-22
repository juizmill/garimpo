# Desenvolvimento

## Ambiente

O WoW Forever roda no **motor moderno** do jogo (o mesmo do retail), com conteúdo do Classic. Por isso:

- profissões vêm de `GetProfessions` / `GetProfessionInfo` (não existe `GetSkillLineInfo`);
- funções de item ficam em `C_Item`; o Garimpo usa `ns.ItemInfo` e `ns.ItemInfoInstant`, que escolhem a função disponível;
- a Casa de Leilão é a moderna (`C_AuctionHouse.ReplicateItems`, `SendSearchQuery`, `PostItem`, `PostCommodity`, `PlaceBid`, `StartCommoditiesPurchase`, `QueryOwnedAuctions`);
- o banco aparece em `Enum.BagIndex`;
- tooltips usam `TooltipDataProcessor`.

O código mantém caminhos alternativos para o cliente antigo quando é simples, mas o alvo é o Forever (`## Interface: 16001`).

## Arquivos

Ordem de carga definida em `Garimpo.toc`:

| Arquivo | Conteúdo |
|---|---|
| `Locales.lua` | Textos em inglês (`enUS`) e português (`ptBR`) e `ns:SetLanguage`. |
| `Core.lua` | Banco de dados salvo, eventos, utilidades (dinheiro, números, datas), leitura de preços (`ns.Price`, `ns.Market`, `ns.Quantity`), comandos. |
| `Data/Items.lua` | Categorias do Ranking com faixas de farm e itens. |
| `Data/Professions.lua` | Profissões, zonas, reagentes (vendedor, farm, fabricação) e rotas. |
| `Data/Vendors.lua` | Gerado: vendedores por item. |
| `Data/Nodes.lua` | Gerado: pontos de nascimento de minérios e ervas. |
| `Analysis.lua` | Bolsas e banco, estatísticas de preço, sugestões, Ranking, medição de g/h, cálculo de rotas e plano de compra. |
| `Scanner.lua` | Scan completo, busca rápida, valor de mercado e histórico, ofertas e compra. |
| `UI/Widgets.lua` | Componentes: caixas, botões, chips, listas com rolagem, barras, etiquetas traduzidas. |
| `UI/Main.lua` | Janela principal e abas. |
| `UI/Ranking.lua`, `Bags.lua`, `Auctions.lua`, `Chart.lua`, `Professions.lua`, `Config.lua` | Uma aba cada da janela principal. `Auctions.lua` também acompanha postagens e vendas. |
| `UI/AuctionPanel.lua` | Painel ao lado da Casa de Leilão, com as abas Postar e Ofertas. |
| `UI/Deals.lua` | Conteúdo da aba Ofertas do painel (`ns.BuildDealsView`). |
| `UI/Tooltip.lua` | Linhas no tooltip dos itens. |
| `UI/Waypoint.lua` | Seta, marcador, pinos no mapa e gravação dos pontos de coleta. |
| `UI/Minimap.lua` | Ícone do minimapa (LibDBIcon quando disponível) e painel de dados. |

## Mensagens internas

`ns:On(msg, fn)` e `ns:Fire(msg, ...)`. Todos os eventos do jogo registrados em `Core.lua` chegam por aqui com o mesmo nome. Mensagens próprias:

| Mensagem | Quando |
|---|---|
| `INIT` | Banco de dados pronto (`ADDON_LOADED`). |
| `READY` | Depois do login. |
| `PRICES` | Um scan completo ou uma busca rápida terminou. |
| `SCAN` | O scanner mudou de estado ou avançou (progresso). |
| `DEALS` | A lista de ofertas ou o estado de uma compra mudou. |
| `BAGS` | Bolsas mudaram, vendedor ou Leilão abriu ou fechou. |
| `MONEY`, `SKILLS`, `ITEMS`, `AUCTIONS`, `LANGUAGE` | Gold, profissões, dados de item, leilões ou idioma mudaram. |

A aba aberta é atualizada sozinha nessas mensagens.

## Adicionar uma rota de profissão

Em `Data/Professions.lua`:

```lua
ns.Routes.alchemy = {
  guide = GUIDE .. "alchemy-leveling-guide",
  tested = 225,                       -- faixas a partir daqui aparecem como "não testado"
  steps = {
    step(1, 60, opt(craft("Minor Healing Potion", "Poção de Cura Menor", 118, 59, { { 2447, 1 }, { 765, 1 }, { 3371, 1 } }))),
    mile("train", 50, RANK.journeyman, 50, 10, { H = { "NPC", 1454 }, A = { "NPC", 1453 } }),
    -- várias opções na mesma faixa: o Garimpo escolhe a mais barata
    step(60, 110, opt(craft(...)), opt(craft(...))),
  },
}
```

- `craft(nomeEn, nomePt, itemDoÍcone, quantidade, reagentes, facção)`: reagentes são `{ itemID, quantidade por craft }`.
- `keep(...)`: igual a `craft`, para produtos guardados e usados depois (rolos de tecido, pedras de amolar). Eles são descontados das etapas seguintes.
- `mile(tipo, skill, título, skillExigido, nívelExigido, quem, notaEn, notaPt)`: `tipo` é `"train"`, `"book"` ou `"quest"`. `quem` usa o uiMapID da cidade ou zona.
- Reagentes novos precisam de uma linha em `R[itemID]`: `VENDOR`, `farm(minutos, zonas)` ou `make(entradas, rendimento, profissão, skill)`.

## Adicionar um texto

Coloque a chave nas duas tabelas de `Locales.lua` e use `L.CHAVE`, ou `W.Label(fontString, "CHAVE")` para que o texto mude junto com o idioma.

## Checagens

Sem cliente do jogo, dá para checar a sintaxe e os textos com Python:

```
pip install luaparser
python tools/checklua.py .     # sintaxe de todos os .lua e textos "..." quebrados em duas linhas
python tools/checkkeys.py .    # chaves usadas x definidas nas duas línguas
```

Erros de execução só aparecem no jogo; use o BugSack para vê-los.
