"""Compile v7 against the preserved user-selected v3 base.

The source game stays in its original banks. Extension code executes from RAM;
only admitted gateways and exact-resource remaps touch original bytes.
"""
from pathlib import Path
import hashlib
import json
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/v4'))
sys.path.insert(0, str(ROOT / 'tools'))
from asm6502 import assemble
from author_v6 import build as character
from nes_codec import encode_tile
from author_gestures import build as gestures
from author_aux import build as auxiliary_art
import re

BASE_SHA = '6530c0abba35334eac2ca3bddb9d56d996b963fb31e1ada0ca042c7e5c124d07'
CODE_ORIGIN = 0x6100
CODE_LIMIT = 0x7E80
RESET_ORIGIN = 0x7F00

def sha(data):
    return hashlib.sha256(data).hexdigest()

def build(revision):
    base = (ROOT / 'output/mopao-v3.nes').read_bytes()
    if sha(base) != BASE_SHA:
        raise ValueError('The exact selected v3 base is required')
    original = base[16:32784]
    lower, upper = bytearray(original[:16384]), bytearray(original[16384:])
    operations = []
    def patch(cpu, new, role, expected=None):
        offset = cpu - 0x8000
        old = original[offset:offset+len(new)]
        if expected is not None and old != bytes.fromhex(expected):
            raise ValueError(f'Gateway admission failed at {cpu:04X}: {old.hex()}')
        bank = lower if offset < 16384 else upper
        index = offset % 16384
        if bank[index:index+len(new)] != old:
            raise ValueError('Overlapping original patch')
        bank[index:index+len(new)] = new
        operations.append({'cpu':cpu, 'old_hex':old.hex(), 'new_hex':new.hex(), 'role':role})

    chr_data = bytearray(base[32784:])
    table = base[0x6E27:0x6EF9]
    patterns, remap, free = {}, {}, []
    for tile in sorted(set(table)-{0xFC}):
        pattern = bytes(chr_data[tile*16:tile*16+16])
        if pattern in patterns:
            remap[tile] = patterns[pattern]
            free.append(tile)
        else:
            patterns[pattern] = tile
            remap[tile] = tile
    patch(0xEE17, bytes(remap.get(tile,tile) for tile in table), 'Exact original player-pixel deduplication')
    tiles, poses = character(free)
    for tile, pixels in tiles.items():
        chr_data[tile*16:tile*16+16] = encode_tile(pixels)
    gesture_tiles, gesture_pairs = gestures(chr_data,[tile for tile in free if tile not in tiles])
    for tile,pixels in gesture_tiles.items():chr_data[tile*16:tile*16+16]=encode_tile(pixels)
    spare=[tile for tile in free if tile not in tiles and tile not in gesture_tiles]
    if len(spare)<2:raise ValueError('Fan requires2 proven spare tiles')
    fan_pixels=[[int(c) for c in row] for row in ['0000222222220000','0022222222222200','0221221221221220','2212212212212212','0021221221221200','0002121221210000','0000012211000000','0000003300000000']]
    for column,tile in enumerate(spare[:2]):chr_data[tile*16:tile*16+16]=encode_tile([row[column*8:column*8+8] for row in fan_pixels])
    # Author the HUD glyph at the CHR owner before sprite/background pagination.
    # A later mutation of chr_data would be discarded by expanded_chr.
    rows=['11111111','00011000','00011000','00011000','00011000','00011000','00011000','00000000']
    chr_data[0x116*16:0x117*16]=bytes([int(row,2) for row in rows]+[0]*8)
    expanded_chr,extra_art=auxiliary_art(chr_data,list(tiles))
    for pose in extra_art:poses.append({'name':pose['name'],'tiles':pose['templates'][0],'small_tiles':pose['templates'][1],'medium_tiles':pose['templates'][2],'sprite_palette_selectors':[0,0,0,0,2,2,2,2],'small_palette_selectors':[0,0,2,2],'medium_palette_selectors':[0,0,2,2,2,2]})
    gesture_source='\nPlayerGestureTiles:\n.byte '+','.join(f'${tile:02x}' for name in ['brace_big','brace_small','body_palm'] for tile in gesture_pairs[name])+'\n'
    templates, pointers = [], []
    for size, key, palettes in [('Big','tiles','sprite_palette_selectors'), ('Small','small_tiles','small_palette_selectors'), ('Medium','medium_tiles','medium_palette_selectors')]:
        for index, pose in enumerate(poses):
            label = f'Template{size}{index}'
            pointers.append(label)
            values = []
            for slot, (tile,palette) in enumerate(zip(pose[key],pose[palettes])):
                values.append(tile)
            templates.append(label+':\n.byte '+','.join(f'${x:02x}' for x in values))
    pointers_source = '\nTemplatePointers:\n.word '+','.join(pointers)+f'\nSizePointerOffsets:\n.byte $00,${len(poses)*2:02x},${len(poses)*4:02x}\n'
    source = (ROOT/'tools/v7/aux_state.asm').read_text(encoding='utf-8')+'\n'+'\n'.join((ROOT/f'tools/v7/{name}.asm').read_text(encoding='utf-8') for name in ['runtime','physics','events','graphics','interactions','cooperation','object_interactions','palm_interactions','player_gestures','bank_gate','platform_ram','props_ram']) + gesture_source+'\nFanPropTiles:\n.byte '+','.join(f'${tile:02x}' for tile in spare[:2])+'\n'
    origin, code, symbols, listing = assemble(source)
    if origin != CODE_ORIGIN or origin+len(code)>CODE_LIMIT:
        raise ValueError(f'Code range exceeds owned RAM: {origin:04X}..{origin+len(code):04X}')
    imports='\n'.join(f'{name} = ${at:04x}' for name,at in symbols.items())+'\n'
    aux_source=imports+'\n'.join((ROOT/f'tools/v7/{name}.asm').read_text(encoding='utf-8') for name in ['auxiliary','aux_input','aux_motion','aux_physical','aux_platform','aux_graphics','cache_original'])+'\n'+'\n'.join(templates)+pointers_source
    helpers=['GroundAtNpc','BodyClear','GetPartnerDelta','BeginNpcJump','NearbyNpcDanger','StompNativeEnemy','ReadPoint','IsSolid','MoveHorizontal','MoveVertical','PlatformGroundContact','CoopTouchSound']
    for name in helpers:
        aux_source+='\nAux'+name+':\n PHP\n PHA\n LDA #<'+name+'\n STA AuxNativePtr\n LDA #>'+name+'\n STA AuxNativePtr+1\n PLA\n PLP\n JMP AuxNativeCall\n'
    # 6502 has no long conditional branches; expand only the roomy ROM bank.
    opposite={'BEQ':'BNE','BNE':'BEQ','BCC':'BCS','BCS':'BCC','BMI':'BPL','BPL':'BMI','BVC':'BVS','BVS':'BVC'}
    relaxed=[]
    for line in aux_source.splitlines():
        match=re.fullmatch(r'\s*(BEQ|BNE|BCC|BCS|BMI|BPL|BVC|BVS)\s+(\w+)\s*',line)
        if match:
            name,target=match.groups();skip=f'AuxLongSkip{len(relaxed)}';relaxed.extend([f' {opposite[name]} {skip}',f' JMP {target}',skip+':'])
        else:relaxed.append(line)
    aux_source='\n'.join(relaxed)
    aux_origin,aux_code,aux_symbols,aux_listing=assemble(aux_source)
    if aux_origin!=0x8000 or len(aux_code)>16384:raise ValueError('Auxiliary bank exceeds16KiB')
    symbols.update({name:at for name,at in aux_symbols.items() if name not in symbols})
    image = bytearray(0x1F00)
    image[:len(code)] = code
    image[RESET_ORIGIN-CODE_ORIGIN:RESET_ORIGIN-CODE_ORIGIN+0x5A] = original[:0x5A]
    boot = '''
.org $8000
 SEI
 CLD
 LDA #$00
 STA $2000
 STA $2001
 LDX #$ff
 TXS
 LDA #$80
 STA $8000
 LDA #$01
 STA $e000
 LDA #$00
 STA $e000
 STA $e000
 STA $e000
 STA $e000
 JMP $8100
'''
    _, bootstrap, _, _ = assemble(boot)
    patch(0x8000,bootstrap,'Boot gateway; original reset copied byte-for-byte to7F00')
    addon = bytearray(16384)
    addon[:len(bootstrap)] = bootstrap
    loader = '''
.org $8100
 LDA #$00
 STA $8000
 LDA #$01
 STA $8000
 STA $8000
 STA $8000
 LDA #$01
 STA $8000
 LDA #$00
 STA $a000
 STA $a000
 STA $a000
 STA $a000
 STA $a000
 LDA #$01
 STA $c000
 LDA #$00
 STA $c000
 STA $c000
 STA $c000
 STA $c000
 STA $00
 STA $02
 LDA #$90
 STA $01
 LDA #$61
 STA $03
 LDX #$1f
 LDY #$00
CopyPage:
 LDA ($00),Y
 STA ($02),Y
 INY
 BNE CopyPage
 INC $01
 INC $03
 DEX
 BNE CopyPage
 LDA #$00
 LDX #$00
ClearState:
 STA $6000,X
 INX
 BNE ClearState
 JMP RamStart
'''
    loader = loader.replace('JMP RamStart',f"JMP ${symbols['RamStart']:04x}")
    _, loader_bytes, _, _ = assemble(loader)
    addon[0x100:0x100+len(loader_bytes)] = loader_bytes
    addon[0x1000:0x1000+len(image)] = image
    def hook(cpu, expected, symbol, opcode=0x20):
        address = symbols[symbol]
        patch(cpu, bytes([opcode,address&255,address>>8]),symbol,expected)
    hook(0x8175,'20 12 82','FrameHook')
    hook(0x80EA,'20 82 81','PauseCooperationHook')
    hook(0x8E7B,'9d fc 06','RawPartnerPadHook')
    hook(0x814D,'20 c6 81','PreCompanionHook')
    hook(0x80C3,'20 dd 8e','VblankHook')
    hook(0x8808,'48 0a a8','GameTextHook',0x4C)
    hook(0xB15A,'20 64 dc','PlayerTerrainHook')
    hook(0xD853,'a5 09 4a','PlayerEnemyHook',0x4C)
    hook(0xB65A,'8c 11 07','FireballSpawnHook')
    hook(0xBCAD,'20 c1 df','PowerupBGHook')
    patch(0x9069,bytes([0xA9,29]),'30 real new-game lives','a9 02')
    patch(0x8755,bytes([0x16,8,0x29,3,0]),'T8 HUD and decimal life display','16 24 17 24 24')
    for cpu in [0x879B,0x87AE]:
        patch(cpu,bytes([0x16,8,0x24,0x24,0x24]),'T8 name in native time-up/game-over','16 24 17 24 24')
    aux_bank=bytearray(16384);aux_bank[:len(aux_code)]=aux_code
    prg=lower+addon+aux_bank+upper
    chr_data=bytearray(expanded_chr)
    header=bytearray(base[:16]);header[5]=len(chr_data)//8192;header[4]=4;header[6]=0x11;header[7]=0;header[8]=1
    target=bytes(header+prg+chr_data)
    destination=ROOT/f'output/t8-zhenzhen-v7-p{revision:02d}.nes'
    if destination.exists() and destination.read_bytes()!=target:
        raise ValueError('A candidate revision is immutable; increment revision')
    destination.write_bytes(target)
    report={'status':'intermediate-candidate-not-release','producer':'Guarded local 6502 compiler; not REA Evidence','revision':revision,'source_v3_sha256':BASE_SHA,'target_sha256':sha(target),'target_path':str(destination),'mapper':1,'prg_bytes':65536,'chr_bytes':len(chr_data),'auxiliary_art':extra_art,'fan_prop_tiles':spare[:2],'volatile_prg_ram_bytes':8192,'runtime_ram_origin':origin,'runtime_bytes':len(code),'auxiliary_rom_bytes':len(aux_code),'auxiliary_state_range':[0x7e80,0x7f00],'nmi_bank_ownership':'All banked callbacks run inside the original NMI-disabled frame transaction; native bank0 restored before the original817E reenables NMI','runtime_limit':CODE_LIMIT,'reset_copy_ram':RESET_ORIGIN,'state_ram_range':[0x6000,0x6100],'template_cache_ram_range':[0x6040,0x6060],'template_format':'Packed tile IDs; row/column/palette generated once at renderer owner','native_transaction_backup_range':[0x7F80,0x8000],'symbols':symbols,'patch_operations':operations,'authored_pose_names':[pose['name'] for pose in poses],'player_gesture_tiles':gesture_pairs,'character_unique_tiles':len(tiles),'gesture_unique_tiles':len(gesture_tiles),'free_player_tiles':free,'player_tile_remap':{f'{k:02X}':f'{v:02X}' for k,v in remap.items()},'not_complete':['Natural new gameplay, independent native behavior, preservation and final delivery are pending']}
    (ROOT/f'evidence/v7/build-p{revision:02d}.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    (ROOT/f'evidence/v7/auxiliary-listing-p{revision:02d}.json').write_text(json.dumps(aux_listing,indent=2)+'\n',encoding='utf-8')
    (ROOT/f'evidence/v7/runtime-listing-p{revision:02d}.json').write_text(json.dumps(listing,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:report[k] for k in ['revision','target_path','target_sha256','runtime_bytes']},ensure_ascii=False))

if __name__=='__main__':
    build(int(sys.argv[1]) if len(sys.argv)>1 else 1)
