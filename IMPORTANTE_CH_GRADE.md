# ✅ Como a Carga Horária Funciona na Grade de Aulas

## Entendimento Correto

### Na Simulação:
- Você define **livremente** a CH alocada para cada professor em cada disciplina (ex: 60h)
- Você seleciona os **slots/horários** que indicam **quando o professor pode dar aula**
- Os slots são apenas **indicadores de disponibilidade**, não representam a CH

### Na Grade de Aulas:
- A CH é **importada da simulação** através do campo `ch_alocada`
- Os slots mostram **quando as aulas acontecem**
- A CH exibida é a **mesma definida na simulação**, não baseada na quantidade de slots

## Exemplo Correto

**Simulação:**
- Professor João: **60h** alocadas em "Cálculo I"
- Slots selecionados: 4 slots (Segunda-M1, Terça-M1, Quarta-M1, Quinta-M1)
  - Estes slots indicam que João pode dar aula nesses horários

**Resultado na Grade:**
- CH do Professor João em Cálculo I: **60h** ✅
- Horários ocupados: Segunda-M1, Terça-M1, Quarta-M1, Quinta-M1
- A CH é a mesma da simulação, independente da quantidade de slots

## Como Funciona Tecnicamente

### Tabela `grade_aulas`
Cada registro na tabela representa **um slot de horário** e contém:
- `dia`: Dia da semana (Seg, Ter, Qua, etc.)
- `turno`: Manhã, Tarde ou Noite
- `indice`: Índice do horário no turno (1, 2, 3, etc.)
- `disciplina_id`: ID da disciplina
- `professores`: Array com IDs dos professores
- `ch_alocada`: **CH total alocada** para este slot (NOVO)
- `semestre`: Semestre letivo

### Cálculo da CH
Quando você importa da simulação para a grade:
1. O sistema pega a CH alocada de cada professor em cada disciplina
2. Cria um registro para cada slot selecionado
3. Adiciona o campo `ch_alocada` em cada registro
4. Ao calcular a CH total do professor, o sistema usa o valor de `ch_alocada`

### Exemplo de Dados

**Simulação:**
```json
{
  "docente_id": "prof-joao",
  "ch_alocada": 60,
  "slots": ["Segunda-M1", "Terça-M1", "Quarta-M1", "Quinta-M1"]
}
```

**Grade (4 registros criados):**
```json
[
  {
    "dia": "Seg",
    "turno": "Manhã",
    "indice": 1,
    "disciplina_id": "calculo-1",
    "professores": ["prof-joao"],
    "ch_alocada": 60  // ← CH real do professor
  },
  {
    "dia": "Ter",
    "turno": "Manhã",
    "indice": 1,
    "disciplina_id": "calculo-1",
    "professores": ["prof-joao"],
    "ch_alocada": 60  // ← Mesmo valor
  },
  // ... mais 2 registros
]
```

**CH Total do Professor:**
- Sistema identifica que todos os 4 slots são da mesma disciplina
- Usa o valor de `ch_alocada` (60h) ao invés de somar 4 slots
- **Resultado: 60h** ✅

## Compatibilidade com Dados Antigos

O sistema mantém compatibilidade com registros antigos que não têm o campo `ch_alocada`:
- Se `ch_alocada` existe e > 0: usa esse valor
- Se `ch_alocada` não existe ou = 0: calcula baseado em slots (1 slot = 1h)

Isso garante que dados antigos continuem funcionando normalmente.

## Resumo

✅ **Slots = Disponibilidade de horário** (quando o professor pode dar aula)
✅ **CH = Carga horária real** (definida na simulação e importada para a grade)
✅ **Independência**: Você pode ter 60h de CH com apenas 4 slots selecionados

---

**Última atualização:** 2026-02-09
