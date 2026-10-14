"""Original partner poses in separate MMC1 sprite pages; native tiles stay exact."""
from author_v6 import HEAD, BODY
from nes_codec import encode_tile

POSES = ('ball_ready','ball_roll','manual','edge_hand','lifted','fan_cover',
         'fan_peek_left','fan_peek_right','back_pose','platform_seat','brake_hand','back_load')

def build(base_chr, owned_ids):
    pages = [bytes(base_chr[:4096]),bytes(base_chr[4096:])]
    records=[]
    for number,name in enumerate(POSES,2):
        head=[list(row) for row in HEAD]
        body=[list(row) for row in BODY]
        if name in ('ball_ready','ball_roll','platform_seat'):
            body[8:]=[list(row) for row in ['0001111111111000','0011111111111100',
                '0011122212221100','0011122212221100','0011111111111100',
                '0001111111111000','0002222222222000','0002222222222000']]
            if name=='ball_roll':head=head[8:]+head[:8]
        if name in ('edge_hand','brake_hand'):
            body[2:7]=[list(row) for row in ['0011121112111100','0111211111133333',
                '0112111111133333','0111112112110000','0031112112110000']]
        if name in ('lifted','back_load'):
            body[10:]=[list(row) for row in ['0011111111110000','0011111111110000',
                '0011111001110000','0022222001110000','0000000002220000','0000000002220000']]
        if name=='back_pose':
            body[2:7]=[list(row) for row in ['3331121112111333','3331211111211333',
                '0002111111121000','0001112112111000','0001112112111000']]
        if name in ('fan_cover','fan_peek_left','fan_peek_right'):
            # One clearly light fan, attached at the hands; no thrown duplicate.
            for y in range(6,14):
                for x in range(3,14):
                    if abs(x-8)<=min(y-5,5):head[y][x]='2' if (x+y)%3 else '1'
            if name.startswith('fan_peek'):
                side=range(1,6) if name.endswith('left') else range(10,15)
                for y in range(5,10):
                    for x in side:head[y][x]='2'
                head[7][3 if name.endswith('left') else 12]='1'
            body[1:5]=[list(row) for row in ['0011112332111100','0011123332111100',
                '0111213331211110','0112111111121110']]
        if name=='manual':head[0]=list('0000022222200000')
        big=[[int(v) for v in row] for row in head+body]
        small=big[::2]  # Same authored pose, compact16px state.
        medium=big[:16:2]+big[16:]
        page=bytearray(pages[0]);patterns={};tiles={};templates=[]
        for size,pixels in enumerate((big,small,medium)):
            ids=[]
            for row in range(len(pixels)//8):
                for col in range(2):
                    grid=[line[col*8:col*8+8] for line in pixels[row*8:row*8+8]]
                    pattern=encode_tile(grid)
                    if pattern not in patterns:
                        if len(patterns)>=len(owned_ids):raise ValueError('Partner page exceeds owned tile slots')
                        tile=owned_ids[len(patterns)];patterns[pattern]=tile;tiles[tile]=grid
                        page[tile*16:tile*16+16]=pattern
                    ids.append(patterns[pattern])
            templates.append(ids)
        pages.append(bytes(page));records.append({'name':name,'chr_page':number,'templates':templates,'pixels':[big,small,medium],'tile_ids':list(tiles)})
    if len(pages)%2:pages.append(pages[0])
    if len(pages)>16:raise ValueError('Bounded MMC1 CHR page contract exceeded')
    return b''.join(pages),records
