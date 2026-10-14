"""Original indexed engineering art for the supplied long-hair tracksuit character."""
from pathlib import Path
import sys,json
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from nes_codec import encode_tile
HEAD=['0000011111100000','0001111111111000','0011111111111100','0011111111111100',
      '0111122222211110','0111222222221110','0111221221221110','0111221221221110',
      '0111222222221110','0111222222221110','0111122222211110','0111112222111110',
      '0111111221111110','0111111221111110','0111111221111110','0011112222111100']
BODY=['0001112221110000','0011112121111000','0011121112111100','0111211111211110',
      '0112111111121110','0111112112111110','0031112112111300','0001112112111000',
      '0001111111111000','0001111111111000','0001111001111000','0001111001111000',
      '0001111001111000','0001111001111000','0002222002222000','0002222002222000']
def build(free_ids):
    bodies={name:[list(row) for row in BODY] for name in ('stand','walk1','walk2','jump','foot','clap','firecatch','blocked','toe','palms','look')}
    bodies['walk1'][10:]=[list(row) for row in ['0011111001110000','0011111001110000','0011111000111000','0011111000111000','0022222000022200','0022222000022200']]
    bodies['walk2'][10:]=[list(row) for row in ['0001110011111000','0001110011111000','0011100011111000','0011100011111000','0222000022222000','0222000022222000']]
    bodies['jump'][10:]=[list(row) for row in ['0001111111111000','0011111111111000','0011111001110000','0022222001110000','0000000002222000','0000000002222000']]
    bodies['foot'][10:]=[list(row) for row in ['0001111001111000','0001111000111100','0001111000022222','0001111000022222','0002222000000000','0002222000000000']]
    bodies['clap'][2:7]=[list(row) for row in ['0011121112111100','0111211111111000','0112111333333300','0111113333333330','0031112112113300']]
    bodies['firecatch'][2:7]=[list(row) for row in ['0011121112111100','0111211111333333','0112111111111333','0111112112110000','0031112112110000']]
    bodies['blocked'][2:7]=[list(row) for row in ['0011121112111100','0111211111133300','0112111111333300','0111112333111000','0031112332111000']]
    bodies['toe'][3:7]=[list(row) for row in ['0311211111211130','0332111111121330','0031112112113300','0001112112111000']]
    bodies['palms'][2:7]=[list(row) for row in ['0011121112111100','0111211111111333','0112113331133333','0111112112133333','0001112112110000']]
    bodies['firecatch'][6:10]=[list(row) for row in ['0031112112111330','0001112112111333','0001111111111333','0001111111111000']]
    bodies['toe'][14:]=[list(row) for row in ['0002222000222200','0002222000000000']]
    profile_head=['0001111111100000','0011111111110000','0011111111111000','0011112222211000','0011122222221000','0011122122221000','0011122122222100','0011122222222220','0011122222222200','0011112222222100','0011112222221000','0011111222210000','0011111122110000','0011111122110000','0011111122110000','0011111122100000']
    profile_small=['0001111111100000','0011112222210000','0011122222221000','0011122122221000','0011122222222200','0011112222221000','0011111122220000','0011111122100000']
    small_head=['0011111111111100','0111111111111110','0111222222221110','0111221221221110','0111222222221110','0111122222211110','0111112222111110','0011112222111100']
    small_body=['0011112121111100','0111121112111110','0111211111211110','0031112112111300','0001111111111000','0001111001111000','0002222002222000','0002222002222000']
    tiles={};patterns={};poses=[]
    def encode_pixels(pixels):
        ids=[]
        for row in range(len(pixels)//8):
            for column in range(2):
                grid=[line[column*8:column*8+8] for line in pixels[row*8:row*8+8]];pattern=encode_tile(grid)
                if pattern not in patterns:
                    if len(patterns)>=len(free_ids):raise ValueError('Not enough proven reclaimed tile slots')
                    tile=free_ids[len(patterns)];patterns[pattern]=tile;tiles[tile]=grid
                ids.append(patterns[pattern])
        return ids
    for name,body in bodies.items():
        pixels=[[int(v) for v in row] for row in (profile_head if name=='look' else HEAD)]+[[int(v) for v in row] for row in body]
        compact=[list(row) for row in small_body]
        if name=='walk1':compact[4:]=[list(row) for row in ['0011110011110000','0011110011110000','0022220002222000','0022220002222000']]
        elif name=='walk2':compact[4:]=[list(row) for row in ['0001111001111000','0000111100111100','0000222200222200','0000222200222200']]
        elif name=='jump':compact[4:]=[list(row) for row in ['0011111111110000','0011110011110000','0022220001110000','0000000002220000']]
        elif name in ('foot','firecatch'):compact[2]=list('0111211111133333');compact[3]=list('0031112112110000')
        elif name=='clap':compact[2]=list('0111211333333300');compact[3]=list('0031113333333300')
        elif name=='blocked':compact[2]=list('0111211111333300');compact[3]=list('0031112332111300')
        elif name=='toe':compact[2]=list('0331211111211330');compact[3]=list('0031112112113300')
        elif name=='palms':compact[2]=list('0111211331133333');compact[3]=list('0001112112133333')
        if name=='foot':compact[4:]=[list(row) for row in ['0001111001122222','0001111001122222','0002222000000000','0002222000000000']]
        if name=='firecatch':compact[4:7]=[list(row) for row in ['0001111111111330','0001111001111333','0002222002222333']]
        if name=='toe':compact[6:]=[list(row) for row in ['0002222002222000','0002222000000000']]
        active_small_head=profile_small if name=='look' else small_head
        small_pixels=[[int(v) for v in row] for row in active_small_head]+[[int(v) for v in row] for row in compact]
        medium_pixels=[[int(v) for v in row] for row in active_small_head]+[[int(v) for v in row] for row in body]
        poses.append({'name':name,'tiles':encode_pixels(pixels),'sprite_palette_selectors':[0,0,0,0,2,2,2,2],'pixels':pixels,'small_tiles':encode_pixels(small_pixels),'small_pixels':small_pixels,'small_palette_selectors':[0,0,2,2],'medium_tiles':encode_pixels(medium_pixels),'medium_pixels':medium_pixels,'medium_palette_selectors':[0,0,2,2,2,2]})
    return tiles,poses
