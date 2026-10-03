"""Extract unique card faces from the source print sheets into app assets."""

from __future__ import annotations

import subprocess
import tempfile
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
MATERIALS = ROOT / "materials"
OUTPUT = ROOT / "packages/besprotoritsa_app/assets/images/card-art"

ITEMS = """circular-saw laser-cutter exo-gloves pneumo-cannon nailgun flamethrower knife ultrasonic-hammer spacesuit frying-pan last-chance load-bearing-vest engineer-coveralls laser-scalpel pipe-wrench guard-suit tank-top camouflage shirt coveralls lab-coat t-shirt shooter-helmet hauler-uniform implant-agility implant-endurance implant-repair armor-vest implant-science implant-strength laboratory-suit ghb-dtn r69-nic3 gtu-b1c4 c6-car-courier sc0-u7 prot2-ct alarm-bot sc13-nc3 f1t-b07 prot3-ct h3-al""".split()
ITEM_POSITIONS = [(page, cell) for page in range(1, 6) for cell in range(1, 9)]
ITEM_POSITIONS += [(6, 1), (6, 2)]

SPECIAL_ITEMS = "old-cloak assault-rifle shotgun drg-4u swiss-army-knife exoskeleton plague-doctor-mask".split()
SUPPLIES = {
    "nanobots": (1, 1),
    "air-canister": (1, 5),
    "adrenaline-supply": (2, 1),
    "credits": (2, 4),
    "defibrillator": (3, 1),
    "stash": (4, 1),
    "dry-rations": (4, 3),
    "tripwire": (4, 5),
    "gas-cylinder": (5, 1),
    "door-remote": (5, 4),
    "proton-shield": (6, 1),
    "water": (6, 2),
    "adrenaline-x": (7, 1),
    "power-cell": (7, 2),
    "science-stimulant": (7, 4),
    "agility-stimulant": (8, 1),
    "endurance-stimulant": (8, 2),
    "repair-stimulant": (8, 3),
    "strength-stimulant": (8, 4),
    "flashlight": (5, 5),
    "medkit": (5, 7),
    "ration": (6, 6),
}
MONSTERS = {
    "restless": (1, 1),
    "volot": (3, 1),
    "drekovac": (3, 3),
    "vurdalak": (3, 5),
    "plagued": (4, 5),
    "likho": (4, 6),
    "nest": (4, 1),
    "pack": (5, 1),
    "werewolf": (5, 5),
    "ghoul": (6, 1),
    "seeker": (6, 5),
    "mother": (7, 1),
    "viy": (7, 2),
    "swarm": (7, 3),
    "leshy": (7, 4),
    "boil": (8, 1),
}
CONDITIONS = {
    "malaise": (1, 1),
    "concussion": (1, 10),
    "nausea": (2, 1),
    "fracture": (2, 10),
    "shortness-of-breath": (3, 1),
    "adrenaline": (3, 10),
}


def render(pdf: Path, page: int, work: Path) -> Image.Image:
    stem = work / f"{pdf.stem}-{page}"
    subprocess.run(
        ["pdftoppm", "-f", str(page), "-l", str(page), "-singlefile", "-png", "-r", "180", str(pdf), str(stem)],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return Image.open(stem.with_suffix(".png")).convert("RGB")


def crop_card(image: Image.Image, cell: int, columns: int, rows: int) -> Image.Image:
    if columns == 6:
        left, right, top, bottom = 0.084, 0.91, 0.05, 0.98
    else:
        left, right, top, bottom = 0.075, 0.92, 0.08, 0.912
    width, height = image.size
    cell_width = (right - left) * width / columns
    cell_height = (bottom - top) * height / rows
    index = cell - 1
    x0 = int((left * width) + (index % columns) * cell_width)
    y0 = int((top * height) + (index // columns) * cell_height)
    x1 = int((left * width) + (index % columns + 1) * cell_width)
    y1 = int((top * height) + (index // columns + 1) * cell_height)
    return image.crop((x0, y0, x1, y1))


def extract(deck: str, pdf_name: str, mapping: dict[str, tuple[int, int]], grid: tuple[int, int]) -> None:
    pdf = MATERIALS / pdf_name
    columns, rows = grid
    with tempfile.TemporaryDirectory(prefix="besprotoritsa-art-") as temp:
        work = Path(temp)
        rendered: dict[int, Image.Image] = {}
        for card_id, (page, cell) in mapping.items():
            if page not in rendered:
                rendered[page] = render(pdf, page, work)
            face = crop_card(rendered[page], cell, columns, rows)
            face.save(
                OUTPUT / f"{deck}-{card_id}.webp", "WEBP", quality=88, method=6
            )
            if deck == "monster":
                width, height = face.size
                face.crop(
                    (int(width * 0.12), int(height * 0.17),
                     int(width * 0.88), int(height * 0.53))
                ).save(
                    OUTPUT / f"monster-token-{card_id}.webp",
                    "WEBP",
                    quality=90,
                    method=6,
                )


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    extract("item", "колода предметов.pdf", dict(zip(ITEMS, ITEM_POSITIONS, strict=True)), (4, 2))
    extract(
        "item",
        "колода припасов.pdf",
        {
            "pipe": (2, 5),
            "brass-knuckles": (2, 6),
            "helmet": (3, 5),
            "makeshift-armor": (3, 6),
            "welding-mask": (3, 7),
            "cleaver": (3, 8),
        },
        (4, 2),
    )
    extract(
        "item",
        "персонажи.pdf",
        {
            "lucky-socks": (4, 1),
            "spacesuit-mk2": (4, 2),
            "gu4-rd": (4, 3),
            "medic-bag": (4, 4),
            "hard-hat": (4, 5),
            "backpack": (4, 6),
            "pistol": (4, 7),
            "smuggler-mark": (4, 8),
        },
        (4, 2),
    )
    extract("special", "особые предметы.pdf", {key: (1, n) for n, key in enumerate(SPECIAL_ITEMS, 1)}, (4, 2))
    extract("supply", "колода припасов.pdf", SUPPLIES, (4, 2))
    extract("monster", "монстры.pdf", MONSTERS, (4, 2))
    extract("condition", "состояния.pdf", CONDITIONS, (6, 3))
    events = json.loads((ROOT / "content/events.json").read_text())["cards"]
    extract(
        "event",
        "события.pdf",
        {
            card["id"]: (index // 8 + 1, index % 8 + 1)
            for index, card in enumerate(events)
        },
        (4, 2),
    )
    tasks = json.loads((ROOT / "content/tasks.json").read_text())["tasks"]
    extract(
        "task",
        "задачи.pdf",
        {
            task["id"]: (index // 8 + 1, index % 8 + 1)
            for index, task in enumerate(tasks)
        },
        (4, 2),
    )
    quests = json.loads((ROOT / "content/quests.json").read_text())["quests"]
    extract(
        "quest",
        "задания сюжет.pdf",
        {
            quest["id"]: (
                quest["number"] // 8 + 1,
                quest["number"] % 8 + 1,
            )
            for quest in quests
        },
        (4, 2),
    )
    print(f"Extracted {len(list(OUTPUT.glob('*.webp')))} card artworks to {OUTPUT}")


if __name__ == "__main__":
    main()
