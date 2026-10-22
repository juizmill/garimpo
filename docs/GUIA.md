# Guia de uso

Abra com `/garimpo`, pelo ícone do minimapa ou pelo painel de dados (Titan, ElvUI etc.).
A janela pode ser arrastada e lembra a posição.

**Buscar no Leilão:** em qualquer lista do Garimpo, clique com o **botão direito** num item para abri-lo (pelo nome exato) na janela da Casa de Leilão do jogo. Nas linhas de receita e de coleta da rota de profissão, a busca é pelo item da linha. Se o Leilão estiver fechado, o Garimpo avisa no chat para abrir antes.

**Ordenar listas:** em qualquer lista, clique no título de uma coluna (Item, Qtd, Total, Retorno, Lucro...). O primeiro clique ordena textos de A a Z e números do maior para o menor; o segundo inverte. A coluna ordenada aparece em dourado com `^` ou `v`. A rota de profissão não muda de ordem, porque segue o skill.

## Ranking

Mostra cada categoria de item com:

- **Lucro est.** e **g/h**: gold por hora estimado. A conta é *preço atual × quantidade típica por hora* em cada faixa de farm. O Garimpo escolhe a melhor faixa que o seu skill (ou nível, no caso de tecido) alcança. Um `*` depois do nome indica que o seu skill ainda não chega lá e que está sendo mostrado o melhor lugar no geral.
- **24h**: quanto o preço da categoria mudou desde o último dia registrado.
- **Melhor item**: o item que mais pesa no gold por hora.

Quando você farma, o Garimpo mede o gold por hora pelo que você saqueia. Com 15 minutos de dados numa categoria, o valor medido substitui a estimativa e aparece com um `*` dourado. Transmog e Encantamento dependem só dessa medição.

Clique numa categoria para ver o detalhe:

| Coluna | Significado |
|---|---|
| Preço | Valor de mercado no último scan |
| vs. média | Diferença em relação à média dos últimos 7 dias |
| 24h | Variação desde o último dia registrado |
| Visto | Há quantos dias o item apareceu num scan |
| Sugestão | **Vender** (10% acima da média), **Segurar** (10% abaixo) ou **Normal** |

O botão **Marcar no mapa** aponta a seta para a melhor zona daquela faixa.

O botão **Atualizar** (com a Casa de Leilão aberta) faz um scan completo quando permitido, ou uma busca rápida dos itens acompanhados.

O histórico de preços começa no dia em que você instala o addon. As sugestões ficam mais confiáveis depois de alguns dias de scans.

## Bolsas

- **Valor nas bolsas**: soma do preço de mercado de tudo que não está vinculado.
- **Vender agora**: o que está 10% ou mais acima da média de 7 dias.
- **Lixo p/ vendedor**: itens cinza.
- **Incluir banco**: soma o banco também. O Garimpo lê o banco sempre que você o abre.
- **Vender lixo**: vende os itens cinza com o vendedor aberto.
- **Painel do Leilão**: abre o painel de postagem quando a Casa de Leilão está aberta.

## Leilões

Lista o que você postou, seja pelo Garimpo, por outro addon de leilão ou pela tela do próprio jogo. Só fica o que ainda importa:

- **Vendidos** aparecem primeiro, do mais recente para o mais antigo, e ficam até você pegar o gold no correio. O Garimpo confere a caixa de correio quando você a abre: enquanto houver uma carta "Leilão bem-sucedido" com o gold daquele item, ele continua em **Todos**; quando o gold é pego, ele sai de **Todos** e fica só em **Vendidos**. Se a carta não estiver na caixa e a venda tiver mais de 1 hora (o tempo que o correio leva), o Garimpo entende que o gold já foi pego, mesmo que por outro addon de correio.
- **Ativos** vêm depois, do que expira antes para o que expira depois.
- **Expirados e cancelados** saem da lista na hora.
- Com o Leilão aberto, a lista de ativos fica igual à do jogo: quantidade, preço e tempo vêm de lá, e o que o jogo não lista mais sai.

A aba **Vendidos** mostra todas as vendas dos últimos 30 dias, da mais recente para a mais antiga, mesmo depois de você pegar o gold. A aba **Compras** mostra o que você comprou no Leilão nos últimos 30 dias, pelas ofertas do Garimpo ou pela janela do próprio jogo, com quanto pagou. Lances que ainda não venceram não entram.

No topo: leilões ativos (quantidade e valor), gold **a receber no correio** e quanto você **vendeu nos últimos 7 dias**. Ao lado dos filtros aparece a soma do gold da lista mostrada: em **Todos**, o valor dos ativos mais o que está no correio; em **Vendidos**, tudo o que vendeu em 30 dias; em **Compras**, tudo o que gastou em 30 dias.

- **Vendas**: o jogo avisa no chat quando alguém compra. O Garimpo lê esse aviso em qualquer lugar do mundo, marca como vendido e toca o som de caixa registradora.

### Cancelar leilões

Fica na aba **Cancelar** do painel do Leilão. A lista mostra seus leilões ativos com o seu preço por unidade, o menor preço dos outros vendedores e se o leilão está **cortado**.

- Marque a caixa à esquerda de cada leilão (ou clique na linha) e use **Cancelar marcados**. **Selecionar todos** marca a lista inteira.
- **Cancelar cortados** cancela sempre todos os leilões em que outra pessoa está vendendo mais barato, marcados ou não. O primeiro clique (**Conferir cortados**) busca seus itens para ter os preços atuais; depois cada clique cancela um.
- O jogo bloqueia mais de um cancelamento por clique (nenhum addon consegue) e fica com o depósito. O botão mostra quantos faltam ("Cancelar (restam 4)").
- Para ir mais rápido, use a tecla de atalho "Botão da aba aberta" (Opções > Atalhos > AddOns > Garimpo). Na aba Cancelar ela repete o último botão usado ali; aperte várias vezes.

Se houver dois leilões do mesmo item, o aviso do jogo não diz qual vendeu; o Garimpo marca o mais antigo.

## Ofertas (scanner e caçador de ofertas)

Fica na aba **Ofertas** do painel do Leilão, já que as compras só funcionam com a Casa de Leilão aberta. O Garimpo escaneia a Casa de Leilão sozinho, sem outros addons.

- **Scan completo**: lê todos os leilões de uma vez. O jogo permite um a cada 15 minutos; o botão mostra quanto falta. Com a opção ligada na Config, ele começa sozinho ao abrir a Casa de Leilão. O scan é processado aos poucos para não travar o jogo.
- **Conferir ofertas**: lê o Leilão inteiro (pelo scan completo ou, se ele ainda estiver no intervalo de 15 minutos do jogo, pela varredura por navegação), escolhe as melhores ofertas de tudo o que está à venda e depois busca essas ofertas uma por uma (no máximo 50) para confirmar preço e quantidade reais e trazer o número de cada leilão. Assim a compra passa a ser de um clique. Enquanto isso a lista antiga some e aparece uma animação de carregamento com o progresso.
- A aba Ofertas começa vazia toda vez que você abre o Leilão: as ofertas da visita anterior podem nem existir mais. Elas aparecem depois de **Conferir ofertas** ou de um **Scan completo**. Os quadros "Na sua margem / exibidas" e "Lucro possível" também ficam vazios ao abrir e enquanto o cálculo roda, e só mostram valores quando ele termina.

A busca dos itens que o Garimpo acompanha (categorias do Ranking, reagentes das rotas, bolsas e banco) fica no botão **Atualizar** do Ranking.

O botão **Scan completo** fica no topo do painel do Leilão e vale para todas as abas. Na aba Ofertas, o terceiro quadro do topo mostra o seu gold, que limita o que as ofertas oferecem.

As ofertas comparam o preço de agora com a **média dos dias anteriores**. No primeiro dia de scans ainda não há histórico, então não aparecem ofertas; o Garimpo avisa isso, e a partir do dia seguinte elas aparecem.

Um scan completo vale por **30 minutos**: nesse tempo as ofertas vêm dele, inclusive depois de `/reload` ou de entrar de novo no jogo, e abrir o Leilão não escaneia de novo. Depois de 30 minutos, o Garimpo pede (ou faz sozinho, com a opção ligada) um scan novo.

Cada scan guarda, por item, o **menor preço**, o **valor de mercado** (média dos 15% mais baratos da quantidade à venda) e a **quantidade à venda**, além de um valor por dia para o histórico.

### Lista de ofertas

Mostra sempre as **50 melhores compras que o seu gold paga agora**, não importa quantos itens o scan leu:

1. Primeiro, as que atingem a sua margem (spread e lucro mínimo), do maior lucro para o menor.
2. Se não chegar a 50, completa com os próximos melhores retornos abaixo da margem, em cor apagada.

Cada item aparece uma vez só, com a sua melhor oferta. Clique no nome (ou no **+**) para abrir, logo abaixo, os outros leilões do item: vendedor, quantidade, preço por unidade, retorno e lucro, até 10 leilões, com o leilão da oferta destacado. Se o item veio só do scan completo (sem vendedores), abrir faz uma busca rápida dele.

**Comprar mais de um leilão**: marque a caixa dos outros leilões que quer levar junto com a oferta. A caixa de quantidade de cada um diz quantas unidades (em equipamentos o leilão é inteiro). Uma faixa dourada, maior e destacada, no fim da lista mostra o total da compra (unidades e gold) e o lucro, e muda na hora quando você altera a quantidade da oferta ou de um leilão marcado. O lucro também passa para a linha da oferta.

- **Mercadorias**: o botão da oferta compra tudo numa compra só, somando a quantidade da oferta e as dos marcados. O jogo sempre cobra as unidades mais baratas primeiro, então o preço final é o da cotação que aparece no botão.
- **Equipamentos**: o jogo permite uma compra por clique. O botão vira **Comprar (3)** e cada clique compra o próximo da fila (**Comprar 2/3**...). Um leilão marcado que já foi vendido para outro é pulado. A quantidade da caixa já vem limitada ao que o seu gold paga. No topo, "Na sua margem / exibidas" mostra quantas são de cada tipo.

**Largura das colunas**: arraste a alça no início de cada título para alargar ou estreitar a coluna; o nome do item fica com o espaço restante. Clique duplo na alça volta ao padrão. As larguras ficam salvas.

| Coluna | Significado |
|---|---|
| Disp. | Unidades daquele leilão |
| Paga/un. | O que você paga por unidade. **A compra é sempre por este preço, nunca pelo valor de mercado.** |
| Valor | Valor de mercado por unidade: média dos últimos **7 dias** para reagentes e materiais de profissão (minério, erva, tecido, couro...) e dos últimos **15 dias** para os demais itens. Usado só para calcular o lucro de revender. O rodapé da aba explica isso. |
| Retorno | Lucro sobre o preço pago, já tirando a taxa do Leilão |
| Lucro | Lucro de revender o que você vai comprar agora (quantidade da caixa, ou o leilão inteiro em equipamentos) |
| Qtd. | Quantas unidades comprar (mercadorias) |

Numa mercadoria, o jogo vende as unidades mais baratas primeiro: se você pede 10 e só há 3 naquele preço, as outras 7 vêm pelo preço seguinte. Por isso o botão mostra o **preço total cotado** antes de você confirmar.

Clique em **Retorno** ou **Lucro** (ou em qualquer outro título) para ordenar. Só entram leilões que dão pelo menos o **spread** (lucro desejado) da Config. Com spread de 20% e taxa de 5%, num item de 10g de mercado o Garimpo aceita pagar até 7g 92s. O lucro mínimo, a taxa do Leilão e se equipamentos entram também ficam na Config.

### Comprar

O jogo exige um clique por compra; nenhum addon compra sozinho.

- Ofertas vindas de uma **busca** compram com um clique em **Comprar**.
- Ofertas vindas do **scan completo** não trazem o número do leilão: o primeiro clique (**Localizar**) encontra o leilão e o segundo (**Comprar**) compra.
- **Mercadorias** (minérios, ervas, tecidos e outros itens empilháveis vendidos por unidade) mostram o preço final antes: o botão vira **Comprar 12g 30s** e o clique seguinte confirma. Para desistir, clique no **×** vermelho que aparece dentro do espaço do botão; a quantidade continua visível, travada até confirmar ou cancelar: a cotação é cancelada e o botão volta ao normal. O mesmo × interrompe uma fila de equipamentos ("Comprar 2/3").
- **Quantidade**: a caixa ao lado do **Comprar** diz quantas unidades comprar de uma mercadoria (padrão 10, ajustável na Config). Mudar o número depois do preço aparecer (ou enquanto a cotação é pedida) cancela a cotação e pede uma nova. Se o número passar do que está à venda, ele fica vermelho e o **Comprar** espera até você voltar para uma quantidade que exista. Equipamentos são comprados um leilão por vez, então a caixa fica travada com a quantidade daquele leilão.
- **Conferir no Leilão**: clique com o **botão direito** no ícone ou no nome do item para abri-lo (pelo nome exato) na janela do próprio Leilão e ver ali todas as quantidades e preços.
- **Gold insuficiente**: antes de pedir a compra ao jogo, o Garimpo confere se o seu gold paga (pelo valor estimado e, nas mercadorias, de novo pela cotação antes de confirmar). Se não pagar, abre um aviso no meio da tela com quanto custa e quanto você tem (feche com **OK**, Esc ou clicando fora), e o botão continua livre para você mudar a quantidade.
- **Erro na compra**: se a compra falhar (o preço mudou, o leilão foi vendido para outro...), o botão vira **Recarregar**. O clique busca de novo só aquele item, com preço, quantidade e número do leilão atuais, e o botão volta para **Comprar**. As outras ofertas não são buscadas de novo.
- **Comprar de novo**: o botão continua ativo depois da compra. Em mercadorias, o próximo clique faz uma nova cotação. Em equipamentos, o leilão comprado some e o botão vira **Procurar outro**, que localiza o próximo leilão que ainda seja oferta. Ao lado do nome aparece quanto você já comprou daquele item (`+10`).

### Aba Profissão (lista de compras)

Fica entre **Ofertas** e **Cancelar** e mostra os reagentes que você mandou para a lista em Profissões > Comprar ou farmar. A lista fica salva por personagem até você comprar ou remover os itens.

| Coluna | Significado |
|---|---|
| Faltam | Quantas unidades ainda faltam comprar |
| Disp. | Unidades à venda por outros jogadores na última busca |
| Paga/un. | Preço do leilão mais barato |
| Total | Custo de comprar o que falta, pelos leilões mais baratos |
| Qtd. | Quantas unidades comprar no próximo clique (mercadorias); começa com o que falta |

- **Buscar no Leilão** busca todos os itens da lista, com preços e quantidades reais.
- **Comprar** funciona como na aba Ofertas (Localizar, cotação de mercadorias, Procurar outro), mas aceita o leilão mais barato a qualquer preço.
- **Ver os leilões**: clique no nome do item (ou em **Localizar**) para abrir, logo abaixo dele, a lista dos leilões encontrados: vendedor, preço por unidade, quantidade e total, até 10 leilões. Em equipamentos cada leilão tem seu próprio **Comprar**; em mercadorias a compra é pela quantidade na linha do item, sempre pelos mais baratos. Clique de novo no nome para fechar. O que você compra é descontado da lista, e o item sai quando não falta mais nada.
- **X** remove o item da lista. Marque as caixas (ou **Selecionar todos**) e clique em **Remover marcados** para tirar vários de uma vez.
- Clique com o botão direito no nome para buscá-lo na janela do Leilão.

## Gráfico

Seu gold ao longo do dia de hoje. Cada ganho ou gasto vira um degrau na linha, e o fim da linha é o seu gold agora. No topo: gold no início do dia, agora e a variação. Passe o mouse para ver a hora e o valor. À meia-noite o gráfico recomeça.

## Profissões

Os botões no topo mostram suas profissões, separadas em **Principais** e **Secundárias**.

### Rota

- **Upando agora**: a receita atual, quantos crafts faltam e qual vem depois.
- Quando falta treinar (por exemplo, Alfaiataria 71/75 sem o Artesão), o quadro mostra **Vá agora: Treinador...** com o nome do treinador da sua facção.
- Cada linha traz a faixa de skill, a receita com os reagentes e o custo pelos preços de hoje.
- Quando uma faixa tem mais de uma receita possível, o Garimpo escolhe a mais barata e marca **Mais barata**. Passe o mouse para comparar as opções.
- Linhas em roxo são treinadores, livros e missões. **Clique duas vezes** numa delas (ou no quadro "Vá agora") para a seta apontar para o NPC: o treinador, vendedor ou NPC de missão indicado na rota, ou o treinador mais próximo da sua facção quando qualquer um serve.
- Mineração, Herborismo, Esfolamento e Pesca mostram onde coletar em cada faixa. Clique numa linha para marcar a zona no mapa.

### Comprar ou farmar

Mostra o que falta até o próximo treinador (ou até o skill 300, conforme a Config), já descontando bolsas e banco.

- Digite **quanto quer gastar**. O Garimpo compra primeiro o que mais economiza tempo de farm por gold e manda farmar o resto.
- Itens de vendedor sempre entram como compra.
- **Farmar tudo** e **Comprar tudo** mostram os dois extremos.
- O `*` no preço indica que sai mais barato comprar a matéria-prima e fabricar (por exemplo, comprar minério e fundir).
- Cada reagente que se compra no Leilão tem uma caixa de seleção. Já vêm marcados os que o plano manda comprar; marque ou desmarque o que quiser.
- **Criar lista do leilão** manda os marcados para a aba **Profissão** do painel do Leilão, com a quantidade a comprar (ou tudo o que falta, se o plano manda farmar). Se o item já estava na lista, a quantidade é atualizada. Com o Leilão aberto, o Garimpo já busca os itens e abre a aba.

### Reagente

Clique num reagente da lista para ver:

- **Comprar ou fazer**: custo de comprar pronto, de fabricar a partir da matéria-prima e o tempo de farm.
- **Onde comprar** (itens de vendedor): vendedores da sua facção com zona, coordenadas e distância, o mais próximo primeiro.
- **Onde farmar** (demais itens): zonas com nível, facção e quantidade de nós. As zonas da sua facção e do seu continente vêm primeiro.

Clique numa linha para marcar no mapa e apontar a seta.

## Painel do Leilão

Abre ao lado da Casa de Leilão (opção na Config). Pode ser arrastado e esticado pelo canto inferior direito, mas não fica menor que o tamanho inicial. Tem cinco abas: **Postar** (abaixo), **Ofertas** e **Profissão** (seções acima), **Cancelar** (em Leilões) e **Ignorados** (abaixo).

- No topo, o botão **Scan completo** e a situação do último scan do Leilão inteiro. As buscas item por item (Conferir ofertas, Buscar no Leilão, Localizar) mostram o progresso na própria aba, sem mexer nesse texto.
- Lista os itens marcados para vender, com o menor preço do Leilão, a **margem** e o seu preço.
- Itens que o Garimpo ainda não viu à venda aparecem no fim, **sem preço**, com o botão **Buscar**, que procura o preço no Leilão. Se ninguém estiver vendendo, a linha diz "ninguém vende".
- Nenhum item da bolsa some sem explicação: uma linha dourada acima das opções diz quantos ficaram de fora e por quê (**para segurar**, **ignorados** ou **travados** pelo jogo, como quando o item está no espaço de venda da janela do Leilão). Passe o mouse para ver os nomes. A caixa "Mostrar itens para segurar" também mostra quantos estão ocultos.
- **O que você pagou**: se você comprou o item no Leilão nos últimos 30 dias, o preço sugerido nunca fica abaixo de *o que pagou + o lucro desejado (spread da Config) + a taxa do Leilão*. Quando isso sobe o preço, aparece um `^` verde ao lado dele; passe o mouse no nome para ver a conta. Digitar uma margem para o item ignora esse piso.
- **Margem**: 0% posta pelo menor preço atual do Leilão, 100% posta pelo dobro, valores negativos vendem mais barato. O valor inicial vem da Config (margem padrão ou por categoria) e pode ser mudado item a item.
- **Postar** posta uma pilha; **Postar próximo** vai descendo a lista. O jogo exige um clique por postagem. Para ir mais rápido, defina uma tecla em Opções > Atalhos > AddOns > Garimpo > "Botão da aba aberta" e aperte várias vezes (fora da aba Cancelar ela faz o "Postar próximo").
- **Ignorar**: use **Shift + botão direito** num item e escolha **Ignorar item** (o botão direito sozinho busca o item no Leilão, como em todo o Garimpo) para ele não aparecer mais. A aba **Ignorados** lista esses itens; clique num deles para voltar a mostrá-lo.

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

Em qualquer item com preço: menor preço no Leilão, valor de mercado, média de 7 dias, quantidade à venda, tendência, sugestão e categoria.
