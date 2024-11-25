# find crafting loops from the recipes folder
# used by the crafter to prevent trying to craft emeralds from an emerald block, if it needs emeralds to craft an item (for example)

import json
from pathlib import Path

OUTPUT_FILE = "recipe_loops/loops.json"

def load_all_recipes() -> list[dict]:
    """Load all recipes from the recipes folder
    """
    recipes = []
    for recipe_file in Path("recipes").glob("*.json"):
        if recipe_file.stem.startswith("_"):
            continue

        with open(recipe_file, "r") as f:
            recipe = json.load(f)
            recipes.append(recipe)

    return recipes


mc_colors = (
    "white",
    "light_gray",
    "gray",
    "black",
    "brown",
    "red",
    "orange",
    "yellow",
    "lime",
    "green",
    "cyan",
    "light_blue",
    "blue",
    "purple",
    "magenta",
    "pink"
)

def to_stub(item: str) -> str:
    """Convert an item to a stub
    """
    split = item.split(":")
    if len(split) == 1:
        return split[0]
    return split[1]


def tag_to_items(tag: str) -> list[str]:
    """Convert a tag to a list of items
    """
    if not tag.startswith("#"):
        return [tag]

    load_path = Path("tags", f"{to_stub(tag).lstrip('#')}.json")

    if not load_path.exists():
        print("Tag not found:", tag)
        return [tag]

    with load_path.open("r") as f:
        tag_data = json.load(f)
        values = tag_data["values"]
        new_values = []

        for value in values:
            if value.startswith("#"):
                new_values.extend(tag_to_items(value))
            else:
                new_values.append(value)

        return new_values


def find_loops() -> dict[str, str]:
    """Find crafting loops from the recipes folder
    """
    recipes = load_all_recipes()
    input_output_map = {}

    for recipe_list in recipes:
        for recipe in recipe_list:
            output_item = recipe["output"]["id"]
            if output_item not in input_output_map:
                input_output_map[output_item] = set()

            for items in recipe["input"].values():
                for item in items:
                    for expanded_item in tag_to_items(item):
                        input_output_map[output_item].add(expanded_item)

    loops = {}

    for output_item, input_items in input_output_map.items():
        for input_item in input_items:
            if input_item in input_output_map and output_item in input_output_map[input_item]:
                if input_item == output_item:
                    continue
                if any(mc_color in input_item for mc_color in mc_colors) and any(mc_color in output_item for mc_color in mc_colors):
                    # filter out colored blocks
                    continue
                input_stub = input_item.split(":")[1]
                output_stub = output_item.split(":")[1]
                
                if input_stub not in loops:
                    loops[input_stub] = [output_stub]
                else:
                    loops[input_stub].append(output_stub)

    return loops


def main():
    loops = find_loops()

    print(f"Found {len(loops)} loops:")
    for loop, loop2 in loops.items():
        print(f" - {loop} -> {loop2}")

    with Path(OUTPUT_FILE).open("w") as f:
        json.dump(loops, f, indent=4)

    print(f"Saved to {OUTPUT_FILE}")

if __name__ == '__main__':
    main()