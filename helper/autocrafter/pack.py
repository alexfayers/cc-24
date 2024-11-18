# Pack json recipe files into a single file

import json
from pathlib import Path
from typing import Iterator, Optional

SOURCE_DIR = "recipe"
OUTPUT_DIR = "recipe_prepared"


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


def ingredient_to_string(ingredient: dict) -> str | list[str]:
    """Convert an ingredient to a string

    Args:
        ingredient (dict): The ingredient to convert

    Returns:
        str: The string representation of the ingredient
    """
    value = None

    if isinstance(ingredient, dict):
        if "item" in ingredient:
            value = ingredient["item"]
        elif "tag" in ingredient:
            value = f"#{ingredient['tag']}"
        else:
            raise Exception(f"Unknown ingredient key: {ingredient}")
        return value

    elif isinstance(ingredient, list):
        return [ingredient_to_string(v) for v in ingredient]

    else:
        raise Exception(f"Unknown ingredient type: {ingredient}")



def prepare_recipe(recipe: dict) -> Optional[dict]:
    """Convert the recipe into something easily usable by the autocrafter.

    Args:
        recipe (dict): The recipe to prepare

    Returns:
        dict: The prepared recipe
    """
    recipe_map = {}

    if recipe["type"] == "minecraft:crafting_shaped":
        for key, value in recipe["key"].items():
            search = ingredient_to_string(value)
            if isinstance(search, str):
                search = [search]

            for search_val in search:
                for row_index, row in enumerate(recipe["pattern"]):
                    for column_index, column in enumerate(row):
                        if column == key:
                            # convert the row and column index into a slot index
                            slot = row_index * 3 + column_index + 1
                            if slot in recipe_map:
                                recipe_map[slot].append(search_val)
                            else:
                                recipe_map[slot] = [search_val]

    elif recipe["type"] == "minecraft:crafting_shapeless":
        for index, ingredient in enumerate(recipe["ingredients"]):
            slot = index + 1
            search = ingredient_to_string(ingredient)
            if isinstance(search, str):
                search = [search]

            for search_val in search:
                if slot in recipe_map:
                    recipe_map[slot].append(search_val)
                else:
                    recipe_map[slot] = [search_val]
    else:
        return None

    prepared_recipe = {
        "input": recipe_map,
        "output": {
            "id": recipe["result"]["id"],
            "count": recipe["result"]["count"]
        }
    }

    return prepared_recipe


def pack_recipes() -> None:
    """Pack all recipes into a single file
    """
    output_dir = Path(OUTPUT_DIR)
    output_dir.mkdir(exist_ok=True)

    grouped_recipes = {}
    
    for recipe_file in find_all_recipes():
        with open(recipe_file, "r") as f:
            recipe = json.load(f)

        prepared_recipe = prepare_recipe(recipe)

        if not prepared_recipe:
            continue

        output_item = prepared_recipe["output"]["id"]
        if output_item in grouped_recipes:
            grouped_recipes[output_item].append(prepared_recipe)
        else:
            grouped_recipes[output_item] = [prepared_recipe]


    for output_item, recipes in grouped_recipes.items():
        filename = f"{output_item.split(':')[1]}.json"
        with Path(output_dir, filename).open("w") as f:
            json.dump(recipes, f, indent=4)


if __name__ == "__main__":
    pack_recipes()
