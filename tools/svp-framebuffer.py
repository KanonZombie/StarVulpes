"""Emission helpers for the two sealed VR framebuffer destinations.

Inactive unless the assembly entry defines M4_VR_DMA. Legacy output bytes
remain unchanged. A[F6] is reserved across geometry/face/particle helpers.
"""
def setup(c,prefix,invalid):
    c['lines'].append('        if def(M4_VR_DMA)')
    c['emit'](0x08e0,12,0x08e0,0x0018,0x000c,0xe003,0x003c)
    c['store'](0xf6)
    c['emit'](0x6800,0x1800)
    c['branch'](prefix+'FramebufferReady','z1')
    c['load'](0xf6);c['emit'](0x6800,0x4800)
    c['branch'](invalid,'z0')
    c['label'](prefix+'FramebufferReady')
    c['lines'].append('        endif')

def pm(c,write=False):
    c['lines'].append('        if def(M4_VR_DMA)')
    c['load'](0xf6);c['emit'](0x00e3)
    c['lines'].append('        else')
    c['emit'](0x08e0,0x2000)
    c['lines'].append('        endif')
    c['emit'](0x08e0,0x0818,0x00c0 if write else 0x000c)

def add_base(c):
    c['lines'].append('        if def(M4_VR_DMA)')
    c['emit'](0x86f6)
    c['lines'].append('        else')
    c['emit'](0x8800,0x2000)
    c['lines'].append('        endif')

def checksum(c, prefix):
    """Same wrapped WORD sum; ADD A,PM4 avoids copy/reset per input WORD."""
    c['lines'].append('        if def(M4_VR_DMA)')
    c['emit'](0xe003,0x0810,0,0x0820,'M4_RENDER_WORDS/32')
    c['label'](prefix+'ChecksumDirect')
    c['emit'](0x0031,*([0x800c]*32),0x0013,0x0032,0x2800,1,0x0023)
    c['branch'](prefix+'ChecksumDirect','z0')
    c['lines'].append('        else')
    c['emit'](0x0810,0,0x0820,'M4_RENDER_WORDS/8')
    c['label'](prefix+'Checksum')
    for _ in range(8):c['emit'](0xe003,0x003c,0x8001,0x0013)
    c['emit'](0x0032,0x2800,1,0x0023)
    c['branch'](prefix+'Checksum','z0')
    c['lines'].append('        endif')
