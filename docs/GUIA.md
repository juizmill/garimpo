# Guia de uso

Abra com `/garimpo`, pelo ícone do minimapa ou pelo painel de dados (Titan, ElvUI etc.).
A janela pode ser arrastada e lembra a posição.

## Ranking

Mostra cada categoria de item com:

- **Lucro est.** e **g/h**: gold por hora estimado. A conta é *preço atual × quantidade típica por hora* em cada faixa de farm. O Garimpo escolhe a melhor faixa que o seu skill (ou nível, no caso de tecido) alcança. Um `*` depois do nome indica que o seu skill ainda não chega lá e que está sendo mostrado o melhor lugar no geral.
- **24h**: quanto o preço da categoria mudou desde o último dia registrado.
- **Melhor item**: o item que mais pesa no gold por hora.

Quando você farma, o Garimpo mede o gold por hora pelo que você saqueia. Com 15 minutos de dados numa categoria, o valor medido substitui a estimativa e aparece com um `*` dourado. Transmog e Encantamento dependem só dessa medição.

Clique numa categoria para ver o detalhe:

| Coluna | Significado |
|---|---|
| Preço | Preço atual no Leilão (Auctionator) |
| vs. média | Diferença em relação à média dos últimos 7 dias |
| 24h | Variação desde o último dia registrado |
| Visto | Há quantos dias o Auctionator viu o item no Leilão |
| Sugestão | **Vender** (10% acima da média), **Segurar** (10% abaixo) ou **Normal** |

O botão **Marcar no mapa** aponta a seta para a melhor zona daquela faixa.

O histórico de preços começa no dia em que você instala o addon. As sugestões ficam mais confiáveis depois de alguns dias de scans.

## Bolsas

- **Valor nas bolsas**: soma do preço de mercado de tudo que não está vinculado.
- **Vender agora**: o que está 10% ou mais acima da média de 7 dias.
- **Lixo p/ vendedor**: itens cinza.
- **Incluir banco**: soma o banco também. O Garimpo lê o banco sempre que você o abre.
- **Vender lixo**: vende os itens cinza com o vendedor aberto.
- **Painel do Leilão**: abre o painel de postagem quando a Casa de Leilão está aberta.

## Leilões

Lista tudo que você postou, seja pelo Garimpo, pelo Auctionator ou pela tela do próprio jogo.

- **Expira em**: tempo restante. Os leilões postados pelo Garimpo usam a duração escolhida; os outros são acertados quando você abre a Casa de Leilão.
- **Situação**: Ativo, Vendido, Expirou ou Encerrado (cancelado ou sumiu sem aviso).
- **Vendas**: o jogo avisa no chat quando alguém compra. O Garimpo lê esse aviso em qualquer lugar do mundo, marca como vendido e toca o som de caixa registradora.
- **Limpar concluídos**: remove da lista o que já terminou.

Se houver dois leilões do mesmo item, o aviso do jogo não diz qual vendeu; o Garimpo marca o mais antigo.

## Gráfico

Gold do personagem por dia, em 7, 30 ou 90 dias. O valor é registrado ao entrar, a cada hora, a cada mudança de gold e ao sair. O gráfico precisa de pelo menos dois dias de registro. Passe o mouse para ver a data e o valor.

## Profissões

Os botões no topo mostram suas profissões, separadas em **Principais** e **Secundárias**.

### Rota

- **Upando agora**: a receita atual, quantos crafts faltam e qual vem depois.
- Quando falta treinar (por exemplo, Alfaiataria 71/75 sem o Artesão), o quadro mostra **Vá agora: Treinador...** com o nome do treinador da sua facção.
- Cada linha traz a faixa de skill, a receita com os reagentes e o custo pelos preços de hoje.
- Quando uma faixa tem mais de uma receita possível, o Garimpo escolhe a mais barata e marca **Mais barata**. Passe o mouse para comparar as opções.
- Linhas em roxo são treinadores, livros e missões.
- Mineração, Herborismo, Esfolamento e Pesca mostram onde coletar em cada faixa. Clique numa linha para marcar a zona no mapa.

### Comprar ou farmar

Mostra o que falta até o próximo treinador (ou até o skill 300, conforme a Config), já descontando bolsas e banco.

- Digite **quanto quer gastar**. O Garimpo compra primeiro o que mais economiza tempo de farm por gold e manda farmar o resto.
- Itens de vendedor sempre entram como compra.
- **Farmar tudo** e **Comprar tudo** mostram os dois extremos.
- O `*` no preço indica que sai mais barato comprar a matéria-prima e fabricar (por exemplo, comprar minério e fundir).
- **Buscar no Leilão** abre a busca do Auctionator com os itens a comprar.

### Reagente

Clique num reagente da lista para ver:

- **Comprar ou fazer**: custo de comprar pronto, de fabricar a partir da matéria-prima e o tempo de farm.
- **Onde comprar** (itens de vendedor): vendedores da sua facção com zona, coordenadas e distância, o mais próximo primeiro.
- **Onde farmar** (demais itens): zonas com nível, facção e quantidade de nós. As zonas da sua facção e do seu continente vêm primeiro.

Clique numa linha para marcar no mapa e apontar a seta.

## Painel do Leilão

Abre ao lado da Casa de Leilão (opção na Config). Pode ser arrastado e esticado pelo canto inferior direito, mas não fica menor que o tamanho inicial.

- Lista os itens marcados para vender, com o preço do Leilão, a **margem** e o seu preço.
- **Margem**: 0% posta pelo preço atual do Leilão, 100% posta pelo dobro, valores negativos vendem mais barato. O valor inicial vem da Config (margem padrão ou por categoria) e pode ser mudado item a item.
- **Postar** posta uma pilha; **Postar próximo** vai descendo a lista. O jogo exige um clique por postagem.

## Seta de navegação

Aparece quando você marca algo no mapa.

- Mostra direção e distância em jardas.
- Em outro continente, fica cinza e diz para onde ir.
- Continua depois de `/reload` e ao entrar de novo no jogo, até você removê-la pelo botão direito.
- No mapa-múndi: moeda no destino, pontos claros onde os nós nascem (Wowhead) e pontos dourados onde você já coletou.

Para onde ela aponta, em ordem de preferência:

1. Sua área mais movimentada, quando você já tem 5 ou mais coletas na zona.
2. A área com mais nós segundo o Wowhead (minérios e ervas).
3. O centro da zona.

## Tooltip

Em qualquer item com preço: preço no Leilão, média de 7 dias, tendência, sugestão e categoria.
