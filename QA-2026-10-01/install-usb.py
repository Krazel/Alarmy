"""Owner-triggered USB installation; the --help option never connects a phone."""
import hashlib, json, pathlib, runpy, site, sys
root = pathlib.Path(__file__).resolve().parents[1]
folder = root / 'artifact/completion-20261001/installer'
sys.path.insert(0, str(folder)); site.addsitedir(str(folder))
if '--help' in sys.argv:
    sys.argv = ['pymobiledevice3', 'apps', 'install', '--help']
else:
    manifest = json.loads((root / 'artifact/completion-20261001/delivery.json').read_text())
    ipa = root / manifest['localFile']
    if hashlib.sha256(ipa.read_bytes()).hexdigest() != manifest['sha256']:
        raise SystemExit('El IPA no coincide con la candidata verificada.')
    print(f"Instalando Alarma {manifest['version']} ({manifest['build']}) en el iPhone conectado por USB.")
    sys.argv = ['pymobiledevice3', 'apps', 'install', str(ipa)]
runpy.run_module('pymobiledevice3', run_name='__main__')
