# Contribuir com o DualPad

## Commits

Use [Conventional Commits](https://www.conventionalcommits.org/pt-br/) para que cada melhoria apareça na seção correta das notas de versão:

- `feat: descrição` para uma nova funcionalidade (aumenta a versão minor).
- `fix: descrição` para corrigir um problema (aumenta a versão patch).
- `feat!: descrição` ou `BREAKING CHANGE:` para uma mudança incompatível (aumenta a versão major).
- `docs:`, `refactor:`, `perf:` e `chore:` para documentação, reorganização, desempenho e manutenção.

Escreva o resumo no imperativo e explique a alteração no corpo quando o título não for suficiente.

## Pull requests e releases

Toda mudança deve entrar por uma pull request com título Conventional Commit; isso permite ao Release Please identificar as melhorias integradas. O GitHub Actions compila cada pull request. Depois que ela entra em `main`, o Release Please atualiza o changelog e abre uma pull request com a próxima versão. Integrar essa pull request cria uma release `DualPad vX.Y.Z` com notas agrupadas por melhoria e o ZIP do app para macOS.
