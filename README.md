# action-generate-luacheckrc
GitHub action to generate up-to-date .luacheckrc for FG extensions from officially released rulesets.

## Usage

```yml
name: Update .luacheckrc

on:
  workflow_dispatch:
  schedule:
    - cron: 0 1 * * *

jobs:
  generate:
    runs-on: ubuntu-latest
    name: generate new .luacheckrc
    steps:
      - uses: actions/checkout@v3
        with:
          fetch-depth: 0

      - name: Generate new .luacheckrc
        uses: FG-Unofficial-Developers-Guild/action-generate-luacheckrc@v1
        with:
          token: ${{ secrets.PAT_TOKEN }}

      - name: Create pull request
        uses: peter-evans/create-pull-request@v3
        with:
          title: Update .luacheckrc
          commit-message: "test: update .luacheckrc"
          branch: update-luacheckrc
          delete-branch: true
```

## Arguments

* `target-path`: Path to generated `.luacheckrc`. Defaults to `.luacheckrc`.
* `header-path`: Path to `.luacheckrc` header, where you can put your own settings in. Defaults to `.luacheckrc_header`.
* `std`: A string such as `+dnd35e+pfrpg` which will pre-select definitions in the generated file. 
* `token`: A GitHub PAT to allow access to private repos.

## License
The Unlicense
