"""Replay the actual release emulator in an isolated profile (Windows only)."""
import argparse
import base64
import csv
import hashlib
import json
from pathlib import Path
import shutil
import struct
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
ROM_SHA = 'c3baec6b9c555cd1b1170e38d9d88f64805c08629144c01f0e8dcf9c5916e315'
EXE_SHA = 'b4c647051c6b3cc7ea709c02056150ac50c65f0fc1d38bfefa51c26f7f4ff875'

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def profile_checks(path):
    text = path.read_text(encoding='utf-8-sig')
    entries = dict(line.split(' ', 1) for line in text.splitlines() if ' ' in line)
    pad = base64.b64decode(entries['GamePadConfig_V2'].split('base64:', 1)[1], validate=True)
    commands = base64.b64decode(entries['FCEUD_CommandMapping_V2'].split('base64:', 1)[1], validate=True)
    ports = struct.unpack('<3I', base64.b64decode(entries['"InputType"'].split('base64:', 1)[1]))
    assert len(pad) == 4416 and len(commands) % 92 == 0
    assert ports[:2] == (1, 1)
    assert entries['RAMInitOption'] == '2'
    assert entries['frameSkipAmt'] == '0'
    assert [struct.unpack_from('<I', pad, 92*i+8)[0] for i in range(8)] == [33,32,31,28,200,208,203,205]
    assert [struct.unpack_from('<I', pad, 1104+92*i+8)[0] for i in range(4)] == [18,19,16,17]
    for offset in range(0, len(commands), 92):
        count = struct.unpack_from('<I', commands, offset+24)[0]
        code = struct.unpack_from('<I', commands, offset+8)[0]
        assert not (count == 1 and commands[offset] == 0 and code in (16,17)), 'Bare Q/W command conflict'
    return {'ram_zero':True, 'two_ports':True, 'Q_W_configured':True, 'Q_W_hotkey_conflicts':False, 'frameskip':0}

def verify(portable, output):
    assert sha(portable / 'game/t8-zhenzhen-v7.nes') == ROM_SHA
    assert sha(portable / 'emulator/fceux64.exe') == EXE_SHA
    profile = profile_checks(portable / 'emulator/fceux.cfg')
    record = json.loads((ROOT / 'web/tests/fixtures/natural-v7-manual-control-and-return.json').read_text(encoding='utf-8'))
    assert record['rom_sha256'] == ROM_SHA and not record['fixture_writes']
    symbols = json.loads((ROOT / 'verification/historical/build-p17.json').read_text(encoding='utf-8'))['symbols']
    output.mkdir(parents=True, exist_ok=False)
    runtime = output / 'runtime'
    shutil.copytree(portable / 'emulator', runtime)
    keys = ['A','B','select','start','up','down','left','right','E','R','Q','W']
    input_path = output / 'inputs.csv'
    input_path.write_text('\n'.join(','.join(str(int(bool(row.get(key)))) for key in keys) for row in record['input_schedule'])+'\n', encoding='ascii')
    lua = 'local out=' + json.dumps(output.resolve().as_posix()+'/') + '\n'
    lua += 'local keys={' + ','.join(json.dumps(key) for key in keys) + '}\n'
    lua += '''local rows={}
for line in io.lines(out..'inputs.csv') do
 local b={};local n=1
 for v in line:gmatch('[^,]+') do b[keys[n]]=v=='1';n=n+1 end
 rows[#rows+1]=b
end
local report=assert(io.open(out..'trace.csv','w'))
report:write('frame,world,level,mode,life,manual,npcActive\\n')
emu.speedmode('maximum')
for f,b in ipairs(rows) do
 joypad.set(2,{A=b.E or false,B=b.R or false,select=b.Q or false,start=b.W or false})
 b.E=nil;b.R=nil;b.Q=nil;b.W=nil
 joypad.set(1,b)
 emu.frameadvance()
'''
    lua += f" local values={{f,memory.readbyte(0x75f)+1,memory.readbyte(0x75c)+1,memory.readbyte(0xe),memory.readbyte(0x75a)+1,memory.readbyte({symbols['AuxManual']}),memory.readbyte({symbols['Active']})}}\n"
    lua += ''' report:write(table.concat(values,',')..'\\n');report:flush()
 if f==310 then gui.savescreenshotas(out..'first-level.png') end
end
report:close()
local marker=assert(io.open(out..'complete.txt','w'));marker:write('complete');marker:close()
emu.exit()
'''
    lua_path = output / 'replay.lua'
    lua_path.write_text(lua, encoding='ascii')
    startup = subprocess.STARTUPINFO()
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = subprocess.SW_HIDE
    args = [str((runtime/'fceux64.exe').resolve()),'-pal','0','-no8lim','0','-turbo','0','-lua',str(lua_path.resolve()),str((portable/'game/t8-zhenzhen-v7.nes').resolve())]
    started = time.monotonic()
    with (output/'stdout.log').open('w') as stdout, (output/'stderr.log').open('w') as stderr:
        process = subprocess.Popen(args, cwd=runtime, startupinfo=startup, stdout=stdout, stderr=stderr)
        try:
            code = process.wait(timeout=45)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
            raise RuntimeError('Owned release emulator did not complete within45 seconds')
    assert code == 0 and (output/'complete.txt').exists()
    with (output/'trace.csv').open(newline='') as stream:
        rows = [{key:int(value) for key,value in row.items()} for row in csv.DictReader(stream)]
    assert len(rows) == len(record['input_schedule'])
    first = rows[309]
    assert (first['world'],first['level'],first['mode'],first['life']) == (1,1,8,30), first
    assert rows[374]['manual'] == 1, rows[374]
    assert rows[-1]['manual'] == 0 and rows[-1]['life'] == 30, rows[-1]
    assert any(row['npcActive'] != 0 for row in rows[310:])
    roundtrip = profile_checks(runtime/'fceux.cfg')
    result = {'status':'passed','producer':'Actual official FCEUX2.7.0 cold process; natural controller route, no runtime RAM writes',
              'rom_sha256':ROM_SHA,'emulator_sha256':EXE_SHA,'frames':len(rows),'elapsed_seconds':time.monotonic()-started,
              'cold_first_level':first,'manual_control_at375':rows[374],'final':rows[-1],
              'profile':profile,'saved_profile':roundtrip,
              'scope':'Power-on1-1/30 lives, S summon, Q manual control and return, persisted input configuration; physical desktop key events not injected. Historical45 native replays used an earlier binary.'}
    (output/'result.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(result,ensure_ascii=False,indent=2))

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('portable', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    verify(args.portable.resolve(), args.output.resolve())
