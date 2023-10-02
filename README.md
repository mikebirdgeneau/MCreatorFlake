# MCreatorFlake

An **Impure** and **Non-Hermetic** Flake for easily installing/running MCreator versions

Installing it for Forge 1.16.5:

`nix profile install github:MathiasSven/MCreatorFlake#forge1_16_5 --no-write-lock-file --impure`

Installing for the most recent version of MCreator:

`nix profile install github:MathiasSven/MCreatorFlake --no-write-lock-file --impure`

Running without installing a version meant for datapacks on 1.18.x:

`nix run github:MathiasSven/MCreatorFlake#datapack1_18_x --no-write-lock-file --impure`

### All versions as of writing:

`nix flake show github:MathiasSven/MCreatorFlake --no-write-lock-file`
```bash
├───apps
│   └───x86_64-linux
│       ├───bedrock1_18_x: app
│       ├───bedrock1_19_x: app
│       ├───bedrock1_20_x: app
│       ├───datapack1_16_x: app
│       ├───datapack1_18_x: app
│       ├───datapack1_19_2: app
│       ├───datapack1_19_4: app
│       ├───datapack1_19_x: app
│       ├───datapack1_20_1: app
│       ├───default: app
│       ├───forge1_16_5: app
│       ├───forge1_18_2: app
│       ├───forge1_19_2: app
│       ├───forge1_19_4: app
│       └───forge1_20_1: app
└───packages
    └───x86_64-linux
        ├───bedrock1_18_x: package 'MCreator2022-2'
        ├───bedrock1_19_x: package 'MCreator2023-2'
        ├───bedrock1_20_x: package 'MCreator2023-3'
        ├───datapack1_16_x: package 'MCreator2022-2'
        ├───datapack1_18_x: package 'MCreator2023-1'
        ├───datapack1_19_2: package 'MCreator2023-2'
        ├───datapack1_19_4: package 'MCreator2023-3'
        ├───datapack1_19_x: package 'MCreator2023-1'
        ├───datapack1_20_1: package 'MCreator2023-3'
        ├───default: package 'MCreator2023-3'
        ├───forge1_16_5: package 'MCreator2022-2'
        ├───forge1_18_2: package 'MCreator2023-1'
        ├───forge1_19_2: package 'MCreator2023-2'
        ├───forge1_19_4: package 'MCreator2023-3'
        └───forge1_20_1: package 'MCreator2023-3'
```
