# Validação

## Automatizada

- 12 testes Elm aprovados: palavras e pontuação, leitura, meta, atualização isolada, IDs e criação, limite de cem textos, exclusão até estado vazio, busca e filtros, round-trip de backup, versões inválidas, identidades repetidas, limites e recuperação da seleção.
- Elm compilado com --optimize e Vite gerando HTML, CSS, fontes e JavaScript estáticos no prefixo /margem/.
- npm audit sem vulnerabilidades na instalação da entrega.

## Navegador

- Criação e edição de texto; sete palavras contadas no exemplo de teste.
- Título, corpo e caderno recuperados após reload.
- Modo foco oculta a navegação; Escape a recupera.
- Busca sem resultados e limpeza; categoria de proposta e navegação entre fichas.
- Criação por proposta preserva os textos anteriores.
- Modal contém Tab e devolve o foco; Escape cancela.
- Remoção e desfazer; remoção da última entrada abre estado vazio; novo texto recupera o editor.
- Importação inválida rejeitada sem alterar os dados. Backup válido exige confirmação e restaura texto, caderno e preferências.
- Markdown baixado e conteúdo verificado no arquivo gerado.
- Layout revisado em 320, 390, 768 e 1280 px; telas de edição, índice, sementes e percurso sem overflow horizontal da página.

## Limites

Sem auditoria com todos os leitores de tela e sem pontuação Lighthouse declarada. A aplicação não oferece nuvem, colaboração ou sincronização entre abas; múltiplas abas usam o último salvamento. A estimativa de leitura considera 200 palavras por minuto. Os totais mostram apenas o conteúdo atual, incluindo as fixtures iniciais.
