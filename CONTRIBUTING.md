# Contribuir com o DualPad

## Commits

Use [Conventional Commits](https://www.conventionalcommits.org/pt-br/) para que cada melhoria apareça na seção correta das notas de versão:

- `feat: descrição` para uma nova funcionalidade (aumenta a versão minor).
- `fix: descrição` para corrigir um problema (aumenta a versão patch).
- `feat!: descrição` ou `BREAKING CHANGE:` para uma mudança incompatível (aumenta a versão major).
- `docs:`, `refactor:`, `perf:` e `chore:` para documentação, reorganização, desempenho e manutenção.

Escreva o resumo no imperativo e explique a alteração no corpo quando o título não for suficiente.

## Pull requests e releases

Pull requests e atualizações na branch `main` são compilados pelo GitHub Actions. O Release Please agrupa commits desde o último release, atualiza o changelog e abre uma pull request com a próxima versão. Integrar essa pull request cria uma release `DualPad vX.Y.Z` com as notas e o ZIP do app para macOS.
