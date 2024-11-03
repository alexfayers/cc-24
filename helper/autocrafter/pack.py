# Pack json recipe files into a single file

import json
from pathlib import Path
from typing import Iterator

SOURCE_DIR = "recipe"
OUTPUT_FILE = "recipes.json"


def find_all_recipes() -> Iterator[Path]:
    """Find all recipes in the source directory

    Returns:
        Iterator[Path]: A generator for all recipe files
    """
    source_dir = Path(SOURCE_DIR)

    if not source_dir.exists():
        raise FileNotFoundError(f"Source directory '{source_dir}' does not exist")
    
    for file in source_dir.iterdir():
        if file.is_file() and file.suffix == ".json":
            yield file


def pack_recipes() -> None:
    """Pack all recipes into a single file
    """
    output_file = Path(OUTPUT_FILE)

    big_recipe = {}

    for recipe_file in find_all_recipes():
        with open(recipe_file, "r") as f:
            recipe = json.load(f)
        big_recipe[recipe_file.stem] = recipe

    with open(output_file, "w") as f:
        json.dump(big_recipe, f)


if __name__ == "__main__":
    pack_recipes()
