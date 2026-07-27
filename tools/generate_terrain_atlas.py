#!/usr/bin/env python3
"""Build TEKNIK's original 32-logical-pixel HD voxel atlas."""
from __future__ import annotations
import random
from pathlib import Path
from PIL import Image, ImageDraw

L=32; S=2; T=L*S; GW=8; GH=4
C=lambda s: tuple(int(s.lstrip('#')[i:i+2],16) for i in (0,2,4))

def wrap_rect(d,x,y,w,h,c):
    for ox in (-L,0,L):
        for oy in (-L,0,L):
            a,b=x+ox,y+oy; e,f=a+w-1,b+h-1
            if e>=0 and f>=0 and a<L and b<L:
                d.rectangle((max(0,a),max(0,b),min(L-1,e),min(L-1,f)),fill=c)

def base(bg,broad,detail,seed,nb=28,nd=16):
    im=Image.new('RGB',(L,L),C(bg)); d=ImageDraw.Draw(im); r=random.Random(seed)
    for _ in range(nb):
        wrap_rect(d,r.randrange(L),r.randrange(L),r.randint(4,10),r.randint(3,8),C(r.choice(broad)))
    for _ in range(nd):
        wrap_rect(d,r.randrange(L),r.randrange(L),r.randint(2,5),r.randint(1,4),C(r.choice(detail)))
    return im

def grass(seed):
    im=base('#628f3d',['#527b35','#6e9c46','#769f4b','#4b7232','#83a457'],['#3e672c','#91ad61','#5a8637','#739749'],seed,32,18)
    d=ImageDraw.Draw(im); r=random.Random(seed+101)
    for _ in range(14):
        x,y=r.randrange(1,30),r.randrange(2,30); c=C(r.choice(['#3e682d','#8aa85b','#567f34']))
        d.line(((x,y+1),(x+1,y-1)),fill=c)
        if r.random()<.45:d.point((x+2,y),fill=c)
    for _ in range(5):
        x,y=r.randrange(2,29),r.randrange(2,29); d.rectangle((x,y,x+1,y+1),fill=C('#a8a260'))
    return im

def dirt(seed):
    im=base('#765237',['#66452f','#845d3d','#8f6744','#5b3d2b','#98714c'],['#a27c55','#4e3527','#73503a','#8a6245'],seed,27,16)
    d=ImageDraw.Draw(im); r=random.Random(seed+151)
    for _ in range(8):
        x,y=r.randrange(2,28),r.randrange(2,28); c=C(r.choice(['#ad8961','#50392b','#927052']))
        d.rectangle((x,y,x+r.randint(1,2),y+r.randint(1,2)),fill=c)
    for _ in range(3):
        x,y=r.randrange(2,27),r.randrange(3,24); d.line(((x,y),(x+2,y+3),(x+1,y+6)),fill=C('#a27b52'))
    return im

def grass_side(seed):
    im=dirt(seed+200); d=ImageDraw.Draw(im); r=random.Random(seed+300)
    g=[C(x) for x in ['#466f30','#578637','#659642','#78a34d','#3e652b']]
    for x in range(L):
        c=g[(x//5+seed)%len(g)]; d.line(((x,0),(x,5)),fill=c)
        if r.random()<.38:d.line(((x,5),(x,5+r.randint(1,5))),fill=g[(x+2)%len(g)])
    for _ in range(12):
        x=r.randrange(0,27); d.rectangle((x,0,min(31,x+r.randint(3,7)),r.randint(2,4)),fill=r.choice(g))
    for _ in range(4):
        x,y=r.randrange(2,28),r.randrange(10,24); d.line(((x,y),(x+1,y+4),(x,y+8)),fill=C('#a27d56'))
    return im

def stone(seed):
    im=base('#68716e',['#59615f','#747c78','#7d8580','#505856','#89908b'],['#929894','#49514f','#626a67'],seed,25,12)
    d=ImageDraw.Draw(im); r=random.Random(seed+401)
    for _ in range(5):
        x,y=r.randrange(2,22),r.randrange(2,22); n=r.randint(5,10); c=C(r.choice(['#444c4a','#4f5755']))
        d.line(((x,y),(x+n//2,y+1),(x+n,y-1)),fill=c)
        if r.random()<.55:d.line(((x+n//2,y+1),(x+n//2+1,y+5)),fill=c)
    return im

def sand(seed):
    im=base('#b89d65',['#aa8d58','#c4aa72','#d0b77e','#9f8554','#b29660'],['#d8c28a','#967c4e','#bca36c'],seed,24,11)
    d=ImageDraw.Draw(im); r=random.Random(seed+501)
    for _ in range(4):
        y=r.randrange(4,28); x=r.randrange(0,22); d.line(((x,y),(min(31,x+r.randint(7,16)),y)),fill=C(r.choice(['#d7c086','#9d8353'])))
    return im

def ore(colors,seed):
    im=stone(seed); d=ImageDraw.Draw(im); r=random.Random(seed+601)
    for _ in range(6):
        x,y=r.randrange(2,24),r.randrange(2,24); c=C(r.choice(colors)); w,h=r.randint(3,6),r.randint(2,5)
        d.rectangle((x,y,x+w,y+h),fill=c); d.rectangle((x+w//2,max(0,y-2),x+w//2+2,y+1),fill=c)
        if r.random()<.6:d.line(((x+1,y),(x+w-1,y)),fill=tuple(min(255,v+24) for v in c))
    return im

def generate(out):
    atlas=Image.new('RGBA',(GW*T,GH*T),(0,0,0,255)); tiles={}
    for v in range(4):
        tiles[v]=grass(1000+v); tiles[4+v]=grass_side(2000+v); tiles[8+v]=dirt(3000+v)
        tiles[12+v]=stone(4000+v); tiles[16+v]=sand(5000+v)
    tiles[20]=ore(['#aab7b2','#c0cbc6','#879590'],6000)
    tiles[21]=ore(['#c46f45','#a85737','#d58a5e'],6100)
    tiles[22]=ore(['#a87a61','#825947','#c39478'],6200)
    tiles[23]=ore(['#d9aa38','#f0c553','#b98622'],6300)
    for i in range(24,32):tiles[i]=stone(7000+i)
    for i,im in tiles.items():atlas.paste(im.resize((T,T),Image.Resampling.NEAREST).convert('RGBA'),((i%GW)*T,(i//GW)*T))
    out=Path(out); out.parent.mkdir(parents=True,exist_ok=True)
    atlas.convert('RGB').quantize(colors=128,dither=Image.Dither.NONE).save(out,optimize=True)

if __name__=='__main__':generate('assets/textures/terrain_atlas.png')
