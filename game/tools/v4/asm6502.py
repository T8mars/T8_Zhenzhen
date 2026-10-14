"""Small strict two-pass assembler for this project's original 6502 extension.

Opcode encoding is read from the pinned emulator metadata; emitted bytes are
also exercised by an independent native emulator. No external assembler/runtime.
"""
from pathlib import Path
import ast,re
ROOT=Path(__file__).resolve().parents[2]
CPU=(ROOT/'vendor/jsnes/src/cpu.js').read_text(encoding='utf-8')
ROWS=re.findall(r'0x([0-9a-f]+):\s*\{ ins: INS_(\w+), mode: ADDR_(\w+),\s*size: (\d+)',CPU)
OP={}
for code,name,mode,size in ROWS:
    if name not in ('SKB','IGN','NOP') or code=='ea':OP.setdefault((name,mode),(int(code,16),int(size)))
BRANCH={'BCC','BCS','BEQ','BNE','BMI','BPL','BVC','BVS'}
def value(text,symbols):
    text=text.strip();extract=None
    if text.startswith(('<','>')):extract=text[0];text=text[1:]
    text=re.sub(r'\$([0-9a-fA-F]+)',r'0x\1',text)
    def node(n):
        if isinstance(n,ast.Constant) and type(n.value)is int:return n.value
        if isinstance(n,ast.Name):return symbols[n.id]
        if isinstance(n,ast.UnaryOp) and isinstance(n.op,ast.USub):return -node(n.operand)
        if isinstance(n,ast.BinOp):
            a,b=node(n.left),node(n.right)
            if isinstance(n.op,ast.Add):return a+b
            if isinstance(n.op,ast.Sub):return a-b
            if isinstance(n.op,ast.BitOr):return a|b
            if isinstance(n.op,ast.BitAnd):return a&b
            if isinstance(n.op,ast.LShift):return a<<b
        raise ValueError('Unsupported assembler expression: '+text)
    result=node(ast.parse(text,mode='eval').body)
    return result&255 if extract=='<' else (result>>8)&255 if extract=='>' else result
def instruction(line,symbols):
    parts=line.split(None,1);name=parts[0].upper();arg=parts[1].strip() if len(parts)>1 else ''
    expr=arg
    if name in BRANCH:mode='REL'
    elif not arg:mode='IMP'
    elif arg=='A':mode='ACC'
    elif arg.startswith('#'):mode='IMM';expr=arg[1:]
    elif re.fullmatch(r'\(.+,X\)',arg):mode='PREIDXIND';expr=arg[1:-3]
    elif re.fullmatch(r'\(.+\),Y',arg):mode='POSTIDXIND';expr=arg[1:-3]
    elif arg.startswith('(') and arg.endswith(')'):mode='INDABS';expr=arg[1:-1]
    else:
        suffix=arg[-2:] if arg.endswith((',X',',Y')) else ''
        expr=arg[:-2] if suffix else arg
        try:zp=0<=value(expr,symbols)<256
        except KeyError:zp=False
        mode=('ZP' if zp else 'ABS')+suffix.replace(',','')
    if (name,mode) not in OP:raise ValueError(f'Unsupported operation: {line} [{mode}]')
    return OP[(name,mode)],mode,expr
def assemble(source):
    lines=[line.split(';',1)[0].strip() for line in source.splitlines()]
    symbols={};statements=[];pc=None;origin=None
    for line in lines:
        if not line:continue
        if '=' in line:
            key,expr=line.split('=',1);symbols[key.strip()]=value(expr,symbols);continue
        if line.endswith(':'):
            if pc is None or line[:-1] in symbols:raise ValueError('Invalid/duplicate label '+line)
            symbols[line[:-1]]=pc;continue
        if line.startswith('.org '):
            pc=value(line[5:],symbols)
            if origin is None:origin=pc
            statements.append((pc,'.org',line[5:]));continue
        if pc is None:raise ValueError('Missing .org')
        if line.startswith(('.byte ','.word ')):
            directive,args=line.split(None,1);size=len(args.split(','))*(1 if directive=='.byte' else 2)
            statements.append((pc,directive,args));pc+=size
        else:
            (_,size),_,_=instruction(line,symbols);statements.append((pc,'op',line));pc+=size
    result=bytearray();listing=[]
    for at,kind,args in statements:
        if kind=='.org':continue
        offset=at-origin
        if offset<len(result):raise ValueError('Overlapping .org')
        result.extend(bytes(offset-len(result)))
        if kind in ('.byte','.word'):
            size=1 if kind=='.byte' else 2;data=b''.join(value(x,symbols).to_bytes(size,'little') for x in args.split(','))
        else:
            (code,size),mode,expr=instruction(args,symbols);data=bytes([code])
            if size>1:
                n=value(expr,symbols)
                if mode=='REL':
                    n-=at+2
                    if not -128<=n<=127:raise ValueError(f'Branch out of range at{at:04X}: {args}')
                    n&=255
                if not 0<=n<1<<(8*(size-1)):raise ValueError(f'Operand out of range: {args}')
                data+=n.to_bytes(size-1,'little')
        result.extend(data);listing.append({'address':at,'hex':data.hex(),'source':args})
    return origin,bytes(result),symbols,listing
