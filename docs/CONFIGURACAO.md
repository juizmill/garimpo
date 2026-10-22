# Configurações

Todas ficam na aba **Config** e são salvas na conta (valem para todos os personagens).
**Restaurar padrão** volta tudo aos valores abaixo, sem mexer na posição do ícone do minimapa.
Passe o mouse no **(?)** ao lado de uma opção para ver a explicação.

## Geral

| Opção | Padrão | O que faz |
|---|---|---|
| Idioma | Automático | Automático segue o idioma do jogo. Português e English trocam na hora, sem recarregar. |
| Mostrar preços no tooltip dos itens | Ligado | Adiciona as linhas do Garimpo nos tooltips. |
| Mostrar botão no minimapa | Ligado | Mostra ou esconde o ícone. |
| Mostrar a seta de navegação | Ligado | Desligar remove a seta atual. |
| Colocar também o marcador do jogo no mapa | Ligado | Usa o marcador nativo do jogo junto com a seta, quando o cliente oferece. |

## Casa de Leilão

Venda, scan e ofertas ficam juntos nesta seção.

| Opção | Padrão | O que faz |
|---|---|---|
| Abrir o painel junto com o Leilão | Ligado | Mostra o painel do Garimpo ao abrir a Casa de Leilão. |
| Scan completo ao abrir o Leilão | Ligado | Começa um scan completo ao abrir a Casa de Leilão quando o último tem mais de 30 minutos. |
| Tipo de Leilão | Facção (5%) | Quanto o Leilão fica de cada venda: Facção (5%) ou Neutro (15%, como Angra do Butim). Vale para o lucro e para as ofertas. |
| Duração padrão | 24h | 12h, 24h ou 48h. |
| Margem de venda | 0% | Quanto acima do menor preço do Leilão postar. 0% = menor preço, 100% = dobro, negativo = mais barato. |
| Lance inicial | 95% | Lance dos itens que aceitam lance, em % do arremate. |
| Ignorar cortes abaixo do mercado em | 20% | Na aba Cancelar, um corte mais de X% abaixo do valor de mercado (média de 7 dias) aparece como **Muito abaixo**, com aviso no chat, e "Cancelar cortados" o ignora. |
| Ofertas: lucro desejado (spread) | 20% | Lucro sobre o que você paga, já tirando a taxa do Leilão. Preço máximo de compra = *mercado × (1 − taxa) ÷ (1 + spread)*. |
| Ofertas: lucro mínimo | 1g | Esconde ofertas que renderiam menos que isso no total. Aceita ouro, prata e cobre. |
| Ofertas: quantidade a comprar | 10 | Valor inicial da caixa de quantidade ao lado do Comprar (mercadorias vendidas por unidade). |
| Ofertas: só itens com histórico | Ligado | Compara com a média dos dias anteriores (um dia já basta). Desligado, itens vistos só hoje usam o valor de mercado de hoje, menos confiável. |
| Ofertas: incluir equipamentos | Desligado | Equipamentos variam muito de preço; deixe desligado para menos ofertas falsas. |
| Mostrar itens para segurar no painel | Desligado | Inclui itens abaixo da média de 7 dias na aba Postar. |
| Tocar som quando vender | Ligado | Toca o som quando um leilão vende. |
| Som de venda | Caixa registradora | Caixa registradora ou moedas do jogo. **Testar** toca o som escolhido. |
| Margem por categoria | vazio | Substitui a margem de venda naquela categoria. Vazio usa a margem de venda. |

Logo abaixo do lucro mínimo, uma linha junta os números em um exemplo e muda na hora: com 20%, Facção e 1g, ela diz que num item de 10g você compra até 7g 92s, vende por 10g, recebe 9g 50s e só aparecem ofertas com lucro de 1g ou mais.

## Profissões

| Opção | Padrão | O que faz |
|---|---|---|
| Orçamento padrão | 20g | Valor inicial do campo "Quanto quer gastar". Aceita ouro, prata e cobre. |
| Planejar até | Próximo treinador | Calcula a lista de compras até o próximo treinador ou até o skill 300. |
| Contar itens do banco | Ligado | Desconta o que está no banco da lista de compras. |
| Fabricar reagentes quando sair mais barato | Ligado | Considera comprar a matéria-prima e fabricar, quando você tem o skill necessário. |
| Esconder etapas concluídas | Desligado | Esconde da rota o que você já passou. |
| Mostrar profissões que não aprendi | Desligado | Mostra as rotas de todas as profissões. |

## Dados

| Opção | O que faz |
|---|---|
| Zerar g/h medido | Apaga o gold por hora medido pelo seu saque; o Ranking volta a usar estimativas. |

## Salvo por personagem

Ficam por personagem, sem opção na Config: gold do dia para o gráfico, conteúdo do banco,
leilões postados e vendas dos últimos 30 dias, posição da janela, do painel, da seta e o marcador atual.

Itens ignorados no painel do Leilão ficam salvos na conta e não são apagados por **Restaurar padrão**.
