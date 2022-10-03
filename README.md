# action-generate-luacheckrc
GitHub action to generate up-to-date .luacheckrc for WoW addons from [Ketho/BlizzardInterfaceResources](https://github.com/Ketho/BlizzardInterfaceResources) and [Gethe/wow-ui-source](https://github.com/Gethe/wow-ui-source).

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
      - uses: actions/checkout@v2
        with:
          fetch-depth: 0

      - name: Generate new .luacheckrc
        uses: LiangYuxuan/action-generate-luacheckrc@v1

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
* `ui-source-branch`: Branch of Gethe/wow-ui-source to checkout. Defaults to `live`.
* `interface-resources-branch`: Branch of Ketho/BlizzardInterfaceResources to checkout. Defaults to `mainline`.

## License
The Unlicense
