# 🔧 Guia de Migração - Campo ch_alocada

## ⚠️ Status Atual

O código está **parcialmente implementado** e comentado temporariamente para evitar erros. 

**O sistema funciona normalmente**, mas a CH ainda é calculada pela quantidade de slots (método antigo) até você adicionar a coluna no banco.

## 📋 Passos para Ativar a Funcionalidade Completa

### 1. Adicionar a Coluna no Supabase

Acesse o **SQL Editor** no Supabase e execute:

```sql
-- Adiciona a coluna ch_alocada na tabela grade_aulas
ALTER TABLE grade_aulas 
ADD COLUMN ch_alocada NUMERIC DEFAULT 0;

-- Opcional: Adicionar comentário para documentação
COMMENT ON COLUMN grade_aulas.ch_alocada IS 'Carga horária alocada para o professor nesta disciplina (importada da simulação)';
```

### 2. Descomentar o Código

Após adicionar a coluna, você precisa descomentar o código em 3 arquivos:

#### Arquivo 1: `lib/planejamento/simulacao_ch_page.dart`

**Localização:** Linha ~1402

**Antes:**
```dart
final List<Map<String, dynamic>> inserts =
    consolidated.values.map((item) {
  // TODO: Descomentar após adicionar a coluna ch_alocada na tabela grade_aulas
  // Remove o campo ch_professores antes de inserir (não existe na tabela)
  // final Map<String, dynamic> chProfs = item['ch_professores'] ?? {};
  item.remove('ch_professores');

  // Calcula a CH total para este slot
  // double chTotal = 0;
  // for (var ch in chProfs.values) {
  //   chTotal += (ch is num ? ch.toDouble() : 0);
  // }
  // Adiciona o campo ch_alocada ao registro
  // item['ch_alocada'] = chTotal;

  return item;
}).toList();
```

**Depois:**
```dart
final List<Map<String, dynamic>> inserts =
    consolidated.values.map((item) {
  // Remove o campo ch_professores antes de inserir (não existe na tabela)
  final Map<String, dynamic> chProfs = item['ch_professores'] ?? {};
  item.remove('ch_professores');

  // Calcula a CH total para este slot
  double chTotal = 0;
  for (var ch in chProfs.values) {
    chTotal += (ch is num ? ch.toDouble() : 0);
  }
  // Adiciona o campo ch_alocada ao registro
  item['ch_alocada'] = chTotal;

  return item;
}).toList();
```

#### Arquivo 2: `lib/grade_aulas_page.dart`

**Localização:** Linha ~350

**Antes:**
```dart
// Carrega apenas o semestre atual selecionado
// TODO: Adicionar ch_alocada ao select após criar a coluna no banco
final responseGrade = await supabase
    .from('grade_aulas')
    .select(
        'id, dia, turno, indice, disciplina_id, professores, semestre, disciplinas!inner(nome, nome_extenso, periodo, turno, ppc)')
    .eq('semestre', semestreAtual);
```

**Depois:**
```dart
// Carrega apenas o semestre atual selecionado
final responseGrade = await supabase
    .from('grade_aulas')
    .select(
        'id, dia, turno, indice, disciplina_id, professores, semestre, ch_alocada, disciplinas!inner(nome, nome_extenso, periodo, turno, ppc)')
    .eq('semestre', semestreAtual);
```

### 3. Testar

1. Reinicie o aplicativo Flutter (hot restart)
2. Crie uma nova simulação com CH definida
3. Importe para a grade usando "Aplicar na Grade"
4. Verifique se a CH está correta na grade

## 🔍 Como Verificar se Funcionou

### No Supabase:
```sql
-- Verificar se a coluna foi criada
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'grade_aulas' 
AND column_name = 'ch_alocada';

-- Ver os dados após importar
SELECT dia, turno, indice, disciplina_id, professores, ch_alocada 
FROM grade_aulas 
WHERE semestre = '2026.1'
LIMIT 10;
```

### Na Aplicação:
- A CH exibida na grade deve ser a mesma da simulação
- Não deve mais depender da quantidade de slots

## 📊 Exemplo de Dados

**Antes (sem ch_alocada):**
```
Professor João em Cálculo I:
- 4 slots selecionados
- CH calculada: 4h ❌
```

**Depois (com ch_alocada):**
```
Professor João em Cálculo I:
- 4 slots selecionados
- CH alocada na simulação: 60h
- CH na grade: 60h ✅
```

## ⚠️ Importante

- **Não delete** dados antigos da grade antes de adicionar a coluna
- Dados antigos (sem ch_alocada) continuarão funcionando com o cálculo antigo
- Apenas novas importações da simulação usarão o novo sistema

## 🆘 Problemas?

Se após descomentar o código você encontrar erros:

1. Verifique se a coluna foi realmente criada:
   ```sql
   \d grade_aulas
   ```

2. Verifique se o tipo de dados está correto (NUMERIC)

3. Tente fazer um insert manual para testar:
   ```sql
   INSERT INTO grade_aulas (dia, turno, indice, disciplina_id, professores, semestre, ch_alocada)
   VALUES ('Seg', 'Manhã', 1, 'test-id', ARRAY['prof-id'], '2026.1', 60);
   ```

---

**Última atualização:** 2026-02-09
