# Autocrafter helper scripts

This directory contains helper scripts for the autocrafter.

The `recipe` directory contains all recipes for the autocrafter, as extracted from the game files (game.jar/data/minecraft/recipe/)

The `pack.py` script in this directory is used to pack the recipes into a format the autocrafter can use.

The `loop_finder.py` script is used to find loops in the recipes - e.g. emerald can craft into emerald blocks, which can craft back into emeralds.

## Add recipes and tags

- Download recipe folder from mod repo using https://download-directory.github.io/
    - Copy recipes into `raw_recipes` folder
- Download tags `item` folder from mod repo using https://download-directory.github.io/
    - Copy tags into `raw_tags` folder
- Run `python3 pack.py` from the `helper/autocrafter/` dir to pack the recipes into a format the autocrafter can use
- Run `python3 loop_finder.py` from the `helper/autocrafter/` dir to find loops in the recipes
- Commit changes
