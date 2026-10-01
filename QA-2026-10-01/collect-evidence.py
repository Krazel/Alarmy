"""Copy native screenshots and keep traceable hashes without device identifiers."""
import hashlib, json, pathlib, re, shutil, sys
from PIL import Image
source, output = map(pathlib.Path, sys.argv[1:3])
output.mkdir(parents=True, exist_ok=True)
screens = []
for manifest in [source/'manifest.json', source/'compact/manifest.json']:
    if not manifest.exists():
        continue
    for group in json.loads(manifest.read_text()):
        for item in group['attachments']:
            name = item['suggestedHumanReadableName']
            match = re.match(r'(\d{2}-(?:es|en)-.+?)_\d+_', name)
            if not match or not name.endswith('.png'):
                continue
            filename = match[1] + '.png'
            if manifest.parent.name == 'compact':
                filename = 'se-' + filename
            target = output/filename
            shutil.copyfile(manifest.parent/item['exportedFileName'], target)
            with Image.open(target) as im:
                dimensions = list(im.size)
            screens.append({'file':filename, 'device':item['deviceName'],
                            'test':group['testIdentifier'], 'pixels':dimensions,
                            'sha256':hashlib.sha256(target.read_bytes()).hexdigest()})
(output/'manifest.json').write_text(json.dumps(screens,indent=2)+'\n')
print(json.dumps(screens,indent=2))
