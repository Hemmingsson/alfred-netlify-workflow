"""Check the editable icon and reject invalid values in app compatibility fields."""
import copy
import json
from pathlib import Path
import unittest

from jsonschema import Draft202012Validator

ROOT = Path(__file__).resolve().parents[2]
SCHEMA = ROOT / '.agents/skills/compose-app-icon/scripts/icon-schema.json'


class IconSchemaTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        schema = json.loads(SCHEMA.read_text())
        Draft202012Validator.check_schema(schema)
        cls.validator = Draft202012Validator(schema)
        cls.icon = json.loads((ROOT / 'assets/netlifylogo.icon/icon.json').read_text())

    def test_saved_icon_is_valid(self):
        self.validator.validate(self.icon)
        for group in self.icon['groups']:
            for layer in group['layers']:
                if 'image-name' in layer:
                    self.assertTrue((ROOT / 'assets/netlifylogo.icon/Assets' / layer['image-name']).is_file())

    def test_legacy_values_still_validate(self):
        icon = copy.deepcopy(self.icon)
        for group in icon['groups']:
            group['specular'] = True
            group['blur-material'] = 0.5
        self.validator.validate(icon)

    def test_invalid_values_are_rejected(self):
        for field, value in [('specular', 'unknown'), ('blur-material', 1.1), ('blur-material', 'none')]:
            with self.subTest(field=field, value=value):
                icon = copy.deepcopy(self.icon)
                icon['groups'][0][field] = value
                self.assertFalse(self.validator.is_valid(icon))


if __name__ == '__main__':
    unittest.main()
