"""Check translation coverage and format arguments without reading user data."""
import json
import re
from pathlib import Path
root = Path(__file__).resolve().parent
zh = json.loads((root / 'zh-Hans.json').read_text())
en = json.loads((root / 'en.json').read_text())
assert zh.keys() == en.keys(), 'Language keys differ'
for key, value in en.items():
    assert value.strip(), key
    assert re.findall(r'%[.\d]*[df@]', key) == re.findall(r'%[.\d]*[df@]', value), key
for source in root.glob('*.swift'):
    for key in re.findall(r'L\("([^"\\]*(?:\\.[^"\\]*)*)"\)', source.read_text()):
        decoded = json.loads('"' + key + '"')
        assert decoded in en, f'Missing translation: {decoded}'
print(f'Localization checks passed: {len(en)} keys')
