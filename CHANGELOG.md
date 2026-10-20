# Histórico de versões

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
