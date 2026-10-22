# Histórico de versões

## 0.3.9

- Visual novo, seguindo os mockups da interface: janelas com borda dourada e barra de título escura, botões próprios (vermelho com texto dourado nas ações principais, marrom nas demais), fechar em quadrado vermelho, abas e filtros escuros que ficam dourados quando ativos, caixas de seleção que enchem de dourado, campos de texto e barra de rolagem finos, linhas das tabelas com divisória. Hover com transição suave, rolagem suave pela roda do mouse e as telas aparecem com fade.
- Painel do Leilão: nova aba **Profissão**, entre Ofertas e Cancelar, com a lista de compras dos reagentes. A lista fica salva por personagem, tem caixas de seleção com "Selecionar todos", botão **X** para remover um item e **Remover marcados**. Comprar desconta da lista. Clicar no nome (ou em "Localizar") abre logo abaixo do item a lista dos leilões encontrados, com vendedor, preço, quantidade e total; equipamentos podem ser comprados leilão a leilão. O modo "Lista de compras" da aba Ofertas saiu.
- Profissões > Comprar ou farmar: caixa de seleção em cada reagente do Leilão; o botão "Buscar no Leilão" virou **Criar lista do leilão** e manda só os marcados para a aba Profissão.
- Cancelar: as caixas de nome e quantidade viraram uma caixa de seleção em cada leilão, mais "Selecionar todos". "Cancelar marcados" cancela os marcados; "Cancelar cortados" sempre cancela todos os cortados.
- Continua um cancelamento por clique: o jogo bloqueia o segundo no mesmo clique (testado). Os que o servidor não confirmar são enviados de novo.
- Aba Leilões: a lista de ativos fica igual à do Leilão do jogo. Postagens que nunca receberam o número do leilão (mercadorias que o jogo junta) não ficam mais presas na lista.
- Aba Leilões: saíram o filtro "Ativos" e o botão "Limpar vendidos". **Todos** mostra os vendidos à espera no correio e depois os ativos; **Vendidos** mostra o histórico de vendas de 30 dias, que fica mesmo depois de pegar o gold, com um aviso quando não há vendas.
- Aba Leilões: nova opção **Compras**, ao lado de Vendidos, com tudo que você comprou no Leilão nos últimos 30 dias (pelas ofertas do Garimpo ou pela janela do jogo): item, quantidade, quanto pagou e quando.
- Cortados: só contam leilões de outros jogadores. Os seus mais baratos não marcam os seus mais caros como cortados, e o menor preço do scan completo (que pode ser seu) não é mais usado; vale a busca de "Conferir cortados".
- Aba Cancelar: nova coluna **Cortado por**, com o nome do jogador que vende mais barato que você (vem da busca de "Conferir cortados").
- Cortes muito abaixo do mercado (padrão: mais de 20% abaixo da média de 7 dias, ajustável na Config) aparecem como **Muito abaixo**, não contam como cortados e "Cancelar cortados" pula eles. O "Conferir cortados" avisa no chat quem vende, por quanto e quanto abaixo do mercado; o mesmo aviso aparece ao passar o mouse na linha.
- Venda de um leilão que o Garimpo não conhecia também aparece como vendida (sem o valor).
- Nomes "item:123" de itens que não estavam no cache são corrigidos na lista.
- Tecla de atalho (Opções > Atalhos > AddOns > Garimpo > "Botão da aba aberta"): na aba Cancelar cancela o próximo leilão (repetindo o último botão usado ali); nas outras abas faz o "Postar próximo" do rodapé da aba Postar.

## 0.3.8

- Profissões: clique duplo num treinador, livro ou missão da rota (ou no quadro "Vá agora") aponta a seta para o NPC. Posições de todos os treinadores e dos NPCs das rotas, tiradas do Wowhead.
- Painel do Leilão: nova aba **Cancelar**, com seus leilões ativos, o menor preço dos outros e se estão cortados. Cancela por nome exato e quantidade (vazio = tudo) ou só os cortados, um por clique.

## 0.3.7

- Ofertas: tirado o botão "Scan completo" repetido; fica só o do topo do painel. O quadro de situação do scan virou "Gold atual".
- Quando não há histórico de preço, as ofertas dizem isso (antes diziam só "nenhuma oferta no scan").
- Ofertas precisam de só um dia anterior de histórico (antes eram dois).

## 0.3.6

- Um scan completo vale por 30 minutos: as ofertas vêm dele mesmo depois de `/reload` ou relog, e abrir o Leilão só escaneia de novo depois disso.
- Mensagens das ofertas dizem se o scan é recente (e só não teve oferta) ou se está velho e precisa ser refeito.

## 0.3.5

- Ofertas: "Busca rápida" (que sempre buscava os mesmos itens acompanhados) virou **Conferir ofertas**, que busca só os itens da lista de ofertas e deixa cada um pronto para comprar com um clique.
- O modo "Busca" virou **Lista de compras** e só mostra o que veio de "Buscar no Leilão" (Profissões).
- Corrigido o erro ao passar o mouse na alça de largura das colunas (`Deals.lua:271`).

## 0.3.4

- Ofertas: sempre as 50 melhores compras que o seu gold paga; primeiro as dentro da margem, depois as melhores abaixo dela (em cor apagada). No máximo 3 por item.
- A quantidade a comprar já vem limitada ao seu gold.
- Colunas das ofertas com largura ajustável: arraste a alça no título; clique duplo volta ao padrão.

## 0.3.3

- Ofertas: o botão de compra não trava mais depois de comprar; mercadorias cotam de novo e equipamentos procuram o próximo leilão que ainda seja oferta.
- Colunas renomeadas para deixar claro o que se paga: "Paga/un." (preço do leilão) e "Vale" (valor de mercado); "Disp." para as unidades do leilão.
- O lucro mostrado é o da quantidade que você vai comprar.
- Títulos "Lucro" e "Qtd." não ficam mais sobrepostos.

## 0.3.2

- Ofertas: clique duplo no item busca ele (nome exato) na janela do próprio Leilão.
- Ofertas: caixa de quantidade ao lado do Comprar para mercadorias (padrão 10, ajustável na Config).
- Painel do Leilão um pouco mais largo (720) para a nova coluna.

## 0.3.1

- Scan completo com plano B: se a lista de leilões (`ReplicateItems`) não existir ou voltar vazia, o Garimpo escaneia pela navegação do Leilão (todos os itens à venda, com menor preço e quantidade).
- A situação do scan mostra quantos itens foram lidos; a busca rápida continua limitada aos itens acompanhados.

## 0.3.0

- Ordenação por clique no título das colunas em todas as listas (exceto a rota de profissão).
- Ofertas: ordenar por Retorno e Lucro; só aparecem linhas com retorno positivo, inclusive no modo Busca.
- Leilões: vendidos primeiro (mais recentes no topo) e depois os ativos pelo tempo restante. Expirados e cancelados saem na hora; vendidos saem quando o gold é pego no correio. Novo total "A receber no correio".
- Gráfico: só o dia de hoje, acompanhando cada mudança de gold.
- Painel do Leilão: botão direito em um item da aba Postar para ignorá-lo, e aba Ignorados para voltar a mostrar.

## 0.2.4

- Config reorganizada: venda, scan e ofertas juntos na seção Casa de Leilão; nome da opção à esquerda e campo à direita; explicações no "(?)" em vez de texto entre as linhas.
- Taxa do Leilão virou a escolha "Facção (5%)" ou "Neutro (15%)".
- Linha de exemplo ao vivo com o preço máximo de compra, o valor recebido e o lucro mínimo.

## 0.2.3

- A aba Ofertas saiu da janela principal e foi para o painel do Leilão, que agora tem as abas Postar e Ofertas.
- O painel do Leilão ficou mais largo por padrão para caber as colunas das ofertas; continua podendo ser esticado.
- "Buscar no Leilão" (Profissões) abre o painel do Leilão direto na aba Ofertas, modo Busca.

## 0.2.2

- Ofertas pelo **spread**: lucro desejado sobre o preço pago, já tirando a taxa do Leilão. Substitui o "Desconto mínimo".
- Taxa do Leilão configurável (5% nas facções, 15% nos neutros).
- A coluna "Desc." da aba Ofertas virou "Retorno" (lucro sobre o preço pago).

## 0.2.1

- Lucro mínimo, orçamento padrão e "Quanto quer gastar" aceitam ouro, prata e cobre. Os valores antigos, salvos em ouro, são convertidos sozinhos.

## 0.2.0

- Scanner próprio da Casa de Leilão: scan completo (a cada 15 minutos, como o jogo permite) e busca rápida dos itens acompanhados. O Auctionator não é mais usado.
- Valor de mercado e quantidade à venda por item; o tooltip mostra menor preço, valor de mercado e quantidade.
- Aba Ofertas: leilões abaixo do valor de mercado de 7 dias, com lucro de revenda e botão de compra (um clique por compra, como o jogo exige).
- Modo Busca: leilão mais barato de cada item buscado; o botão "Buscar no Leilão" das Profissões usa este modo.
- Painel do Leilão com botão de scan; a margem passa a valer sobre o menor preço atual.
- Novas opções na Config: scan ao abrir o Leilão, desconto mínimo, lucro mínimo, histórico mínimo e equipamentos.

## 0.1.0

Primeira versão.

- Ranking de categorias por gold por hora, estimado pelos preços e medido pelo seu saque.
- Detalhe por categoria com sugestão de vender, segurar ou normal.
- Aba Bolsas com valor, o que vender agora e lixo, incluindo o banco.
- Aba Leilões com tempo para expirar, situação e som de caixa registradora a cada venda.
- Gráfico de gold acumulado em 7, 30 e 90 dias.
- Profissões: rotas de Ferraria, Alfaiataria, Encantamento, Primeiros Socorros, Culinária e Pesca (guias do wow-professions.com) e de Mineração, Herborismo e Esfolamento; receita mais barata por faixa; aviso de treinador; plano de comprar ou farmar com orçamento; onde farmar e onde comprar.
- Painel do Leilão com margem por item, postagem com um clique, arrastável e redimensionável.
- Seta de navegação persistente, pinos no mapa, vendedores e nós do Wowhead.
- Tooltip com preço, média, tendência e sugestão.
- Ícone do minimapa, painel de dados (LibDataBroker) e textos em português e inglês.
