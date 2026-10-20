# Garimpo

Addon para **WoW Forever** que responde uma pergunta: *o que está dando mais gold agora?*
Ele compara os preços da Casa de Leilão, mostra o que vale farmar, vender ou segurar,
acompanha seus leilões e ajuda a upar profissões gastando menos.

Interface em **português e inglês**, com troca na aba Config.

## O que ele faz

| Aba / recurso | Para que serve |
|---|---|
| **Ranking** | Categorias (minérios, ervas, tecidos, couro, encantamento, pesca, transmog) ordenadas pelo gold por hora estimado, com variação em 24h e o melhor item. Clique numa categoria para ver os itens. |
| **Bolsas** | Quanto valem suas bolsas, o que vale vender agora, o que segurar e o lixo para o vendedor. |
| **Leilões** | Tudo que você postou, com tempo para expirar e situação (ativo, vendido, expirado). Toca uma caixa registradora quando algo vende. |
| **Ofertas** (no painel do Leilão) | Scanner próprio da Casa de Leilão e caçador de ofertas: leilões bem abaixo do valor de mercado, com o lucro de revenda e botão de comprar. |
| **Gráfico** | Seu gold acumulado em 7, 30 ou 90 dias. |
| **Profissões** | Rota de cada profissão até o próximo treinador, receita mais barata em cada faixa, plano de comprar ou farmar dentro do seu orçamento, onde farmar e onde comprar. |
| **Config** | Idioma, margens de preço, som, seta, minimapa e opções de profissão. |
| **Painel do Leilão** | Abre junto com a Casa de Leilão, com duas abas: **Postar** (o que vender, com o preço sugerido, um clique por item) e **Ofertas**. |
| **Seta de navegação** | Aponta para a área de farm, para o vendedor mais próximo ou para seus pontos de coleta, com a distância em jardas. |
| **Tooltip** | Preço no Leilão, média de 7 dias, tendência e sugestão em qualquer item. |

## Requisitos

- WoW Forever (cliente `_classic_beta_`).
- Nenhum outro addon é obrigatório: o Garimpo tem o próprio scanner da Casa de Leilão.
- Opcional: qualquer addon que traga o LibDBIcon (BugSack, Questie...) organiza o ícone do minimapa junto com os outros.

## Instalação

1. Copie a pasta `Garimpo` para `World of Warcraft\_classic_beta_\Interface\AddOns\`.
2. Na tela de personagens, em **AddOns**, ative **Garimpo**.
3. Entre no jogo e abra a Casa de Leilão. O primeiro scan completo começa sozinho (opção na Config).
4. Digite `/garimpo`.

O jogo permite um scan completo a cada 15 minutos. As sugestões e as ofertas ficam melhores depois de alguns dias de scans, porque comparam o preço de hoje com a média de 7 dias.

Ao atualizar o addon com arquivos **novos** (sons, imagens, dados), feche o jogo e abra de novo.
O `/reload` só recarrega arquivos que já existiam.

## Comandos

| Comando | O que faz |
|---|---|
| `/garimpo` ou `/gar` | Abre e fecha a janela |
| `/garimpo config` | Abre a aba Config |
| `/garimpo reset` | Volta a janela, o painel do Leilão e o tamanho do painel ao padrão |
| `/garimpo som` | Toca o som de venda |

Ícone do minimapa: clique abre a janela, botão direito abre a Config, arrastar move.
Seta: arrastar move, botão direito abre o menu para removê-la.

## Documentação

- [Guia de uso](docs/GUIA.md): cada aba em detalhe.
- [Configurações](docs/CONFIGURACAO.md): todas as opções.
- [Dados e fontes](docs/DADOS.md): de onde vêm preços, rotas, vendedores e nós, e como gerar de novo.
- [Desenvolvimento](docs/DESENVOLVIMENTO.md): organização do código, como adicionar rotas e textos.
- [Histórico de versões](CHANGELOG.md).

## Créditos

- Rotas de profissão inspiradas nos guias do [wow-professions.com](https://www.wow-professions.com/forever).
- Locais e preços de vendedores e pontos de nascimento de minérios e ervas: [Wowhead](https://www.wowhead.com/classic) (dados do Classic).
---

## English

Garimpo is a gold-making addon for **WoW Forever**. It scans the Auction House on its own,
ranks item categories by estimated gold per hour, values your bags, finds deals listed well
below market value (with a buy button), tracks your auctions with a cash register sound on
each sale, charts your gold, and plans profession leveling: cheapest recipe per skill range,
buy-or-farm within a budget, where to farm and where to buy, with an on-screen navigation arrow.

Switch the interface language (Automatic, Português, English) in the **Settings** tab.
No other addon required. Open with `/garimpo`. See the table above for commands.
