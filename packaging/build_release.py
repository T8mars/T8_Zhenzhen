"""Build the portable Windows ZIP from exact verified game/emulator inputs."""
import argparse
import hashlib
from pathlib import Path
import shutil
import zipfile

ROOT = Path(__file__).resolve().parents[1]
EXPECTED = {
    'rom': 'c3baec6b9c555cd1b1170e38d9d88f64805c08629144c01f0e8dcf9c5916e315',
    'runtime': 'f851d608fc21bc7d289d25ef92cb29ca6c96a21c3df28f82aab2a8328df1f9ff',
    'source': '56e851e74c6ccb1e31a030cd60ae12cac10cfe7181a562a02e14d367043005aa',
}

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def copy(source, target):
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)

def build(rom, runtime, source, output):
    for label, path in [('rom',rom),('runtime',runtime),('source',source)]:
        if sha(path) != EXPECTED[label]:
            raise ValueError(f'Unexpected {label} input; preserve it and investigate')
    output.mkdir(parents=True, exist_ok=False)
    portable = output / 'T8-Zhenzhen-v7-Windows'
    for name in ['Play-v7.cmd','开始游戏-v7.cmd']:
        copy(ROOT/'packaging/Play-v7.cmd', portable/name)
    copy(ROOT/'packaging/fceux-v7.cfg', portable/'emulator/fceux.cfg')
    copy(rom, portable/'game/t8-zhenzhen-v7.nes')
    copy(ROOT/'game/output/t8-zhenzhen-v7.bps', portable/'game/t8-zhenzhen-v7.bps')
    with zipfile.ZipFile(runtime) as archive:
        selected = {'fceux64.exe','lua5.1.dll','lua51.dll','7z_64.dll','auxlib.lua','fceux.chm','taseditor.chm'}
        for item in archive.infolist():
            if item.is_dir():
                continue
            if item.filename not in selected and not item.filename.startswith('palettes/'):
                continue
            target = portable/'emulator'/item.filename
            if not target.resolve().is_relative_to((portable/'emulator').resolve()):
                raise ValueError('Unexpected upstream archive path')
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(archive.read(item))
    copy(source, portable/'licenses/FCEUX-2.7.0-source.zip')
    copy(ROOT/'docs/FCEUX-COPYING.txt', portable/'licenses/FCEUX-COPYING.txt')
    for name in ['controls.md','third-party.md','validation.md','v7-gameplay.png','first-level.png']:
        copy(ROOT/'docs'/name, portable/'docs'/name)
    copy(ROOT/'verification/portable-startup.json', portable/'verification/portable-startup.json')
    readme = '''T8与贞贞 v7 · Windows64便携版

1. 将整个ZIP解压到一个文件夹；不要直接在压缩软件里运行。
2. 双击“开始游戏-v7.cmd”，也可双击Play-v7.cmd。
3. 按Enter开始，方向键移动，F跳跃，D加速/火球，S召唤贞贞。
4. 新互动用Q/W/E/R，详细组合见docs/controls.md。

初始30命。贞贞与T8一起变大变小，可踩怪、撞砖与提供借头二段跳。
请选单人模式使用新互动。不需要安装Node或Python，不需要另找ROM。
关闭后退出游戏；存档可用模拟器菜单。不同版本存档请分开保存。

游戏与网页源码：https://github.com/T8mars/T8_Zhenzhen
发行页：https://github.com/T8mars/T8_Zhenzhen/releases/tag/v7.0.0
许可与模拟器完整对应源码在licenses/，验证范围在docs/validation.md。
'''
    (portable/'README-先读.txt').write_text(readme, encoding='utf-8-sig')
    names = sorted(path for path in portable.rglob('*') if path.is_file())
    lines = [f'{sha(path)}  {path.relative_to(portable).as_posix()}' for path in names]
    (portable/'SHA256SUMS.txt').write_text('\n'.join(lines)+'\n', encoding='utf-8')
    target_zip = output/'T8-Zhenzhen-v7-Windows.zip'
    with zipfile.ZipFile(target_zip, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in sorted(portable.rglob('*')):
            if path.is_file():
                archive.write(path, path.relative_to(output).as_posix())
    with zipfile.ZipFile(target_zip) as archive:
        assert archive.testzip() is None
        for path in portable.rglob('*'):
            if path.is_file():
                assert archive.read(path.relative_to(output).as_posix()) == path.read_bytes()
    print(f'Built and byte-verified: {target_zip} ({target_zip.stat().st_size} bytes)')

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--rom', required=True, type=Path)
    parser.add_argument('--fceux-zip', required=True, type=Path)
    parser.add_argument('--fceux-source', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    build(args.rom.resolve(), args.fceux_zip.resolve(), args.fceux_source.resolve(), args.output.resolve())
