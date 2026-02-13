# Documentação de Níveis de Acesso - Secretaria Digital DRI

Este documento detalha os níveis de acesso e quais funcionalidades cada perfil pode visualizar e interagir no sistema.

## Estrutura de Níveis

| Nível | Identificador | Descrição | Cards Visíveis |
| :--- | :--- | :--- | :--- |
| **0** | **Visitante / Novo** | Acesso inicial após login via Google. | Apenas "Minhas Bancas" (se houver participação). |
| **1** | **Secretaria Operacional** | Foco em processos documentais. | **Secretaria** |
| **2** | **Coordenação** | Gestão acadêmica e relatórios. | **Gestão de Semestres** (Leitura), **Bancas de TCC**, **Secretaria**, **Relatórios** |
| **3** | **Coordenação Especial** | Edição acadêmica completa. | **Gestão de Semestres**, **Bancas de TCC**, **Secretaria**, **Relatórios**, **Catálogo de Disciplinas** |
| **4** | **Administrador** | Controle total do sistema. | **Todos os cards** (incluindo Gestão de Usuários) |

### Restrições Específicas Nível 2 (Somente Leitura em Semestres)

O Nível 2 pode visualizar tudo no módulo de Semestres, mas não pode realizar alterações:
- **Catálogo de Disciplinas**: SEM ACESSO (Oculto).
- **Página Principal**: Não pode criar, editar datas ou remover semestres da visão.
- **Grade Horária**: Não pode lançar aulas, importar simulações ou excluir horários.
- **Simulação**: Não pode criar/excluir simulações, alterar alocações ou ignorar disciplinas.

*Nota: O Nível 3 possui as mesmas permissões que o Nível 2, mas com permissão de escrita/edição completa no módulo de Semestres e acesso ao Catálogo de Disciplinas.*

### Restrições Específicas Nível 2 (Somente Leitura em TCC)

- **Situação da Documentação**: Pode visualizar a lista e status, mas NÃO PODE alterar o status de entrega (Docs, TCC, Termo).

---

## Implementação Técnica

Os acessos são controlados verificando o campo `access_level` na tabela `users_access` do Supabase.

### Lógica de Exibição (Dashboard Principal)

Para adicionar ou modificar acessos aos novos cards, siga o padrão de verificação do `userAccessLevel`:

- **Card Bancas de TCC**: Visível para nível == 0 OU nível >= 2. (Oculto para Nível 1).
  - *Dentro deste card, usuários Nível 0 veem apenas o link para "Minhas Bancas".*
- **Card Secretaria**: Visível para níveis >= 1.
- **Card Semestres**: Visível para níveis >= 2.
- **Card Relatórios**: Visível para níveis >= 2.
- **Card Usuários**: Visível apenas para nível >= 4.

### Exemplo de Código (React/Next.js)

```tsx
{userAccessLevel >= 1 && (
  <BentoCard
    href="/secretaria"
    title="Secretaria"
    // ...
  />
)}
```

## Segurança de Rota

Além da visibilidade dos cards, cada página possui uma proteção interna no `useEffect`:

```tsx
useEffect(() => {
    const checkAccess = async () => {
        const { data: { session } } = await supabase.auth.getSession()
        if (!session) {
            router.push('/login')
            return
        }

        const { data: accessData } = await supabase
            .from('users_access')
            .select('access_level')
            .eq('id', session.user.id)
            .single()

        if (!accessData || accessData.access_level < PERMISSAO_REQUERIDA) {
            router.push('/')
            return
        }
    }
    checkAccess()
}, [])
```
