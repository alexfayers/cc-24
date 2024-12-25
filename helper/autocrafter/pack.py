# Pack json recipe files into a single file

import json
from pathlib import Path
from typing import Iterator, Optional

RECIPE_SOURCE_DIR = "raw_recipes"
RECIPE_OUTPUT_DIR = "recipes"

TAG_SOURCE_DIR = "raw_tags"
TAG_OUTPUT_DIR = "tags"


def find_all_json(source_dir: Path) -> Iterator[tuple[Path, Path]]:
    """Find all recipes in the source directory

    Returns:
        Iterator[Path]: A generator for all recipe files
    """
    if not source_dir.exists():
        raise FileNotFoundError(f"Source directory '{source_dir}' does not exist")

    for directory in source_dir.glob("*"):
        if directory.is_dir():
            for file in directory.rglob("*.json"):
                if file.is_file():
                    yield file, file.relative_to(directory)


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

    elif isinstance(ingredient, str):
        return ingredient
    else:
        raise Exception(f"Unknown ingredient type: {ingredient}")


def crafting_slot_to_turtle_slot(slot: int) -> int:
    """Convert a crafting table slot to a turtle slot

    Args:
        slot (int): The crafting table slot

    Returns:
        int: The turtle slot
    """
    if slot > 3:
        slot += 1
    if slot > 7:
        slot += 1

    return slot


def prepare_recipe(recipe: dict) -> Optional[dict]:
    """Convert the recipe into something easily usable by the autocrafter.

    Args:
        recipe (dict): The recipe to prepare

    Returns:
        dict: The prepared recipe
    """
    recipe_map = {}

    if recipe["type"] in ("minecraft:crafting_shaped", "computercraft:transform_shaped"):
        for key, value in recipe["key"].items():
            search = ingredient_to_string(value)
            if isinstance(search, str):
                search = [search]

            for search_val in search:
                for row_index, row in enumerate(recipe["pattern"]):
                    for column_index, column in enumerate(row):
                        if column == key:
                            # convert the row and column index into a crafting table
                            # 0,0 -> 1
                            # 0,1 -> 2
                            # 0,2 -> 3
                            # 1,0 -> 4
                            # 1,1 -> 5
                            # 1,2 -> 6
                            # 2,0 -> 7
                            # 2,1 -> 8
                            # 2,2 -> 9

                            slot = row_index * 3 + column_index + 1

                            # convert the crafting table index into the turtle slot index
                            # 1 -> 1
                            # 2 -> 2
                            # 3 -> 3
                            # 4 -> 5
                            # 5 -> 6
                            # 6 -> 7
                            # 7 -> 9
                            # 8 -> 10
                            # 9 -> 11

                            # idk how to do this with math
                            slot = crafting_slot_to_turtle_slot(slot)

                            if slot in recipe_map:
                                recipe_map[slot].append(search_val)
                            else:
                                recipe_map[slot] = [search_val]

    elif recipe["type"] in ("minecraft:crafting_shapeless", "computercraft:transform_shapeless"):
        for index, ingredient in enumerate(recipe["ingredients"]):
            slot = index + 1
            slot = crafting_slot_to_turtle_slot(slot)

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

    recipe_id = recipe["result"].get("id")

    if recipe_id is None:
        recipe_id = recipe["result"].get("item")

    if recipe_id is None:
        print(f"Recipe has no id: {recipe}")
        return

    count = recipe["result"].get("count", None)
    if not count:
        print(f"Force count to 1 for {recipe_id}")
        count = 1
        # return

    prepared_recipe = {
        "input": recipe_map,
        "output": {
            "id": recipe_id,
            "count": count
        }
    }

    for slot in prepared_recipe["input"]:
        for item_index, item in enumerate(prepared_recipe["input"][slot]):
            if not item.startswith("#"):
                item = item.replace(":", "/")
                prepared_recipe["input"][slot][item_index] = item

    prepared_recipe["output"]["id"] = prepared_recipe["output"]["id"].replace(":", "/")

    return prepared_recipe


def pack_recipes() -> None:
    """Pack all recipes into a single file
    """
    output_dir = Path(RECIPE_OUTPUT_DIR)
    output_dir.mkdir(exist_ok=True)

    grouped_recipes = {}
    
    for recipe_file_read, recipe_file_write in find_all_json(Path(RECIPE_SOURCE_DIR)):
        with recipe_file_read.open("r") as f:
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
        output_path = Path(output_dir, f"{output_item.replace(':', '/')}.json")
        # output_path = Path(output_dir, recipe_file_write.stem)
        output_path.parent.mkdir(exist_ok=True, parents=True)

        with output_path.open("w") as f:
            json.dump(recipes, f, indent=4)

    with Path(output_dir, "_complete.json").open("w") as f:
        stub_list = sorted([recipe_file.relative_to(output_dir).as_posix() for recipe_file in output_dir.rglob("*.json") if not recipe_file.stem.startswith("_")])
        json.dump(stub_list, f, indent=4)


def pack_tags() -> None:
    output_dir = Path(TAG_OUTPUT_DIR)
    output_dir.mkdir(exist_ok=True)

    for tag_file_read, tag_file_write in find_all_json(Path(TAG_SOURCE_DIR)):
        with open(tag_file_read, "r") as f:
            tag = json.load(f)

            new_values = []
            for value in tag["values"]:
                if isinstance(value, str):
                    new_values.append(value)
                elif isinstance(value, dict):
                    if "id" in value:
                        dict_value = value["id"].split(":")[1]
                        if value["id"].startswith("#"):
                            dict_value = f"#{dict_value}"
                        new_values.append(dict_value)
                else:
                    continue

            if not new_values:
                continue

            tag["values"] = new_values

        output_path = Path(output_dir, tag_file_write)
        output_path.parent.mkdir(exist_ok=True, parents=True)

        with output_path.open("w") as f:
            json.dump(tag, f, indent=2)



if __name__ == "__main__":
    pack_recipes()
    pack_tags()