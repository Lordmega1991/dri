# Checkpoint: Lógica de Simulação e Grade (v2)
Data: 06/02/2026

## Estado Atual do Sistema

### 1. Cálculo de Carga Horária e Co-regência
- A carga horária agora é tratada como `num` (double) em todo o sistema (`grade_aulas_page.dart`, `grade_pdf_helper.dart`).
- **Regra de Co-regência**: Cada slot ocupado na grade equivale a **1 hora total**. Esta hora é dividida igualmente entre os professores alocados naquele slot.
- Exemplo: Se 2 professores dividem uma aula de 60h (4 slots de 1h cada), cada um recebe 0.5h por slot, totalizando as 2h semanais corretas para cada um.

### 2. Simulação e Alocação
- **Alocação Manual**: Restauramos a seleção manual de horários (M1, M2, T1, T2, N1, N2...) no `DialogAlocacaoDetalhada`.
- **Exportação Fiel**: O processo de "Efetivar na Grade" agora respeita exatamente os slots marcados pelo usuário na simulação.
- **UI Simplificada**: Removida a contagem de "horários esperados" no cartão de período, focando apenas no progresso da carga horária (CH Alocada / CH Total).

### 3. Visualização e PDF
- A barra lateral da grade e o PDF gerado exibem as horas com uma casa decimal (ex: `2.0h`, `1.5h`), garantindo clareza em casos de divisão de turmas.

## Arquivos Modificados
- `lib/grade_aulas_page.dart`: Refatoração da lógica de cálculo e tipos de dados.
- `lib/grade_pdf_helper.dart`: Ajuste nos tipos e formatação do PDF.
- `lib/planejamento/simulacao_ch_page.dart`: Correção da exportação e sintaxe dos loops.
- `lib/planejamento/widgets/dialog_alocacao_detalhada.dart`: Restauração da grade de horários.
- `lib/planejamento/widgets/card_periodo_widget.dart`: Ajuste visual e correção de sintaxe.

## Próximos Passos Sugeridos
- Validar se a exportação de simulações com múltiplos professores em slots diferentes (mas na mesma disciplina) está sendo agrupada corretamente na grade.
- Verificar a geração de PDF para simulações com muitas disciplinas/professores.
