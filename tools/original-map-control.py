"""Bounded executor of selected-ROM map control fragments for correspondence tests."""
def execute(rom,pc,s,z=None):
    """Bounded execution of the actual control fragments, M=16 / X=16."""
    ram={};a=0;x=s['pointer'];y=x;width=16;zero=False;negative=False;carry=True
    stack=[];calls=[]
    fields={0x16ff:('pointer',2),0x16fd:('counter',2),0x1701:('last_z',2),
            0x1703:('delta_z',2),0x1743:('background',2),0x1f15:('flags',2),
            0x16e1:('dma_list',2),0x18b4:('mode',1),0x18b5:('timer',1),0x1ff6:('bank',1)}
    def put(address,value,size):
        for i in range(size):ram[address+i]=(value>>(i*8))&255
    for address,(name,size) in fields.items():put(address,s[name],size)
    put(0x7e45ee,s['brightness'],1)
    put(0x123a,0x3000,2);put(0x3010,s['z'] if z is None else z,2)
    def get(address,size):
        if address<0x2000 or address in ram or address<0x8000:
            return sum(ram.get(address+i,0)<<(8*i) for i in range(size))
        if address==0x7e45ee:return ram[address]
        bank=address>>16 if address>=0x10000 else s['bank']
        offset=(bank&127)*32768+(address&32767)
        return int.from_bytes(rom[offset:offset+size],'little')
    def flags(value):
        nonlocal zero,negative
        zero=value==0;negative=bool(value&(1<<(width-1)))
    def result(continuation):
        for address,(name,size) in fields.items():s[name]=get(address,size)
        if continuation:s['pointer']=x
        if z is not None:s['z']=z
        return continuation
    for _ in range(160):
        op=rom[pc];pc+=1;size=width//8;mask=(1<<width)-1
        if op in (0xc2,0xe2):
            assert rom[pc] in (0x20,0x30);width=16 if op==0xc2 else 8;pc+=1
        elif op==0xbb:x=y
        elif op==0xda:stack.append(x)
        elif op==0xfa:x=stack.pop()
        elif op==0xaa:x=a
        elif op==0x9b:y=x
        elif op==0xe8:x=(x+1)&65535
        elif op in (0xad,0xbd,0xbf,0xaf,0xae,0x8d,0x8e,0x9c,0xed):
            length=3 if op in (0xbf,0xaf) else 2
            address=int.from_bytes(rom[pc:pc+length],'little');pc+=length
            if op in (0xbd,0xbf):address+=x
            if op==0xae:x=get(address,2)
            elif op==0x8d:put(address,a,size)
            elif op==0x8e:put(address,x,2)
            elif op==0x9c:put(address,0,size)
            elif op==0xed:
                value=a-get(address,size)-(not carry);carry=value>=0;a=value&mask;flags(a)
            else:a=get(address,size);flags(a)
        elif op in (0xb5,0x85,0x05):
            address=rom[pc];pc+=1
            if op==0xb5:a=get(address+x,size);flags(a)
            elif op==0x85:put(address,a,size)
            else:a|=get(address,size);flags(a)
        elif op in (0xa9,0x09,0x29,0xc9):
            value=int.from_bytes(rom[pc:pc+size],'little');pc+=size
            if op==0xa9:a=value;flags(a)
            elif op==0x09:a|=value;flags(a)
            elif op==0x29:a&=value;flags(a)
            else:zero=a==value;carry=a>=value;negative=bool((a-value)&(1<<(width-1)))
        elif op==0x0a:carry=bool(a&(1<<(width-1)));a=(a<<1)&mask;flags(a)
        elif op in (0x18,0x38):carry=op==0x38
        elif op in (0xf0,0xd0,0x30):
            delta=int.from_bytes(rom[pc:pc+1],'little',signed=True);pc+=1
            if (op==0xf0 and zero) or (op==0xd0 and not zero) or (op==0x30 and negative):pc+=delta
        elif op in (0x22,0x20):
            length=3 if op==0x22 else 2
            target=int.from_bytes(rom[pc:pc+length],'little');pc+=length
            if target==0xed6f:return result(1)
            calls.append(pc);pc=(target>>16)*32768+(target&32767)
        elif op==0x4c:
            target=int.from_bytes(rom[pc:pc+2],'little');assert target==0xed6f
            return result(1)
        elif op in (0x60,0x6b):
            if calls:pc=calls.pop()
            else:return result(0)
        elif op in (0x08,0x8b):pass # wrappers immediately before JSR dispatcher
        else:raise AssertionError((hex(pc-1),hex(op)))
    raise AssertionError('Original control handler did not terminate')

