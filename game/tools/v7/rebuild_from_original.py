"""Independently reconstruct v7 from the exact, read-only user original."""
from pathlib import Path
import hashlib,sys,json
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'));sys.path.insert(0,str(ROOT/'tools/v7'))
from apply_bps import apply_bps
from build_v7 import build
source=Path(sys.argv[1]).resolve();data=source.read_bytes();sha=lambda b:hashlib.sha256(b).hexdigest()
assert sha(data)=='4473b008df230c7dc071a977c26b0b53426aeb9fff2042935f10e8c4c7457225','Exact original required'
base=apply_bps(data,(ROOT/'output/墨袍扇客-中文改版-v3.bps').read_bytes())
assert sha(base)=='6530c0abba35334eac2ca3bddb9d56d996b963fb31e1ada0ca042c7e5c124d07'
target=ROOT/'output/mopao-v3.nes';target.parent.mkdir(exist_ok=True)
assert target.resolve()!=source
if target.exists():assert target.read_bytes()==base,'Existing base differs; preserve it'
else:target.write_bytes(base)
(ROOT/'evidence/v7').mkdir(parents=True,exist_ok=True)
manifest=json.loads((ROOT/'output/manifest-v7.json').read_text(encoding='utf-8'))
build(manifest['revision'])
final=ROOT/f"output/t8-zhenzhen-v7-p{manifest['revision']:02d}.nes"
manifest=json.loads((ROOT/'output/manifest-v7.json').read_text(encoding='utf-8'))
assert sha(final.read_bytes())==manifest['target_sha256']
assert source.read_bytes()==data
