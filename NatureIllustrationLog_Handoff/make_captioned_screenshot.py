import sys, os
from PIL import Image, ImageDraw, ImageFont, ImageFilter
BOLD='/usr/share/fonts/truetype/crosextra/Carlito-Bold.ttf'
REG='/usr/share/fonts/truetype/crosextra/Carlito-Regular.ttf'
def wrap(d,text,font,maxw):
    words=text.split(); lines=[];cur=''
    for wd in words:
        t=(cur+' '+wd).strip()
        if d.textlength(t,font=font)>maxw and cur: lines.append(cur);cur=wd
        else: cur=t
    return lines+[cur]
def make(src, out, size, head, sub, crop=None):
    W,H=size; land=W>H
    bg=Image.new('RGB',size); d=ImageDraw.Draw(bg)
    top=(46,107,63); bot=(24,64,36)
    for y in range(H):
        t=y/(H-1); d.line([(0,y),(W,y)],fill=tuple(int(top[i]+(bot[i]-top[i])*t) for i in range(3)))
    if land: hs,ss=int(H*0.05),int(H*0.027)
    else: hs,ss=int(min(W*0.075,H*0.036)),int(min(W*0.04,H*0.019))
    fh=ImageFont.truetype(BOLD,hs); fs=ImageFont.truetype(REG,ss)
    y=int(H*(0.045 if land else 0.05))
    for text,font,col in ((head,fh,(255,255,255)),(sub,fs,(214,232,206))):
        for ln in wrap(d,text,font,W*0.86):
            d.text(((W-d.textlength(ln,font=font))/2,y),ln,font=font,fill=col); y+=int(font.size*1.18)
        y+=int(H*0.012)
    shot=Image.open(src).convert('RGBA')
    if crop: shot=shot.crop(crop)
    top_y=y+int(H*0.03)
    scale=min(W*(0.86 if land else 0.82)/shot.width,(H-top_y-int(H*0.035))/shot.height)
    sw,sh=int(shot.width*scale),int(shot.height*scale)
    shot=shot.resize((sw,sh),Image.LANCZOS)
    r=int(min(sw,sh)*0.035)
    mask=Image.new('L',(sw,sh),0); ImageDraw.Draw(mask).rounded_rectangle([0,0,sw-1,sh-1],r,fill=255)
    from PIL import ImageChops
    mask=ImageChops.multiply(mask,shot.getchannel('A'))
    x=(W-sw)//2; off=int(min(W,H)*0.012)
    shimg=Image.new('L',size,0); ImageDraw.Draw(shimg).rounded_rectangle([x,top_y+off,x+sw,top_y+sh+off],r,fill=110)
    shimg=shimg.filter(ImageFilter.GaussianBlur(int(min(W,H)*0.02)))
    bg.paste((10,30,15),(0,0),shimg)
    bg.paste(shot.convert('RGB'),(x,top_y),mask)
    os.makedirs(os.path.dirname(out),exist_ok=True)
    bg.save(out,'PNG')
