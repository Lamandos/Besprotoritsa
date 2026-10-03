"""Regression tests for source-sheet card artwork positions."""

import unittest

from PIL import Image, ImageChops, ImageStat

from tool.extract_card_art import OUTPUT, crop_card, render


class QuestArtPositionTest(unittest.TestCase):
    def test_quest_art_28_and_29_match_their_printed_cells(self):
        from pathlib import Path
        from tempfile import TemporaryDirectory

        from tool.extract_card_art import MATERIALS

        with TemporaryDirectory(prefix="quest-art-test-") as temp:
            sheet = render(MATERIALS / "задания сюжет.pdf", 4, Path(temp))
            expected_cells = {28: 6, 29: 7}
            for quest_number, cell in expected_cells.items():
                with self.subTest(quest=quest_number):
                    expected = crop_card(sheet, cell, columns=4, rows=2)
                    actual = Image.open(
                        OUTPUT / f"quest-quest-{quest_number}.webp"
                    ).convert("RGB")
                    if actual.size != expected.size:
                        expected = expected.resize(actual.size, Image.Resampling.LANCZOS)
                    difference = ImageChops.difference(actual, expected)
                    mean_difference = sum(ImageStat.Stat(difference).mean) / 3
                    self.assertLess(mean_difference, 8)


if __name__ == "__main__":
    import unittest

    unittest.main()
