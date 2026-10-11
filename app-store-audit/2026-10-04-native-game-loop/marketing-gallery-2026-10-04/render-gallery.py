"""Artifact-only composition of approved native pixels. No UI/device/network work."""
from pathlib import Path
from PIL import Image, ImageOps, ImageDraw, ImageFont, ImageFilter
import json, hashlib, math, random, datetime

ROOT=Path(__file__).resolve().parent
REPO=ROOT.parents[2]
FONT=Path('/System/Library/Fonts/Avenir Next.ttc')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
manifest=json.loads((ROOT/'manifest.json').read_text())
freeze=json.loads(Path(manifest['sourceFreeze']['path']).read_text())
assert sha(Path(manifest['sourceFreeze']['path']))==manifest['sourceFreeze']['sha256']
assert freeze['aggregateSHA256']==manifest['sourceFreeze']['aggregateSHA256']
for item in freeze['inputs']:
 assert sha(REPO/item['path'])==item['sha256'],item['path']
assert sha(Path(manifest['ownerNativeApproval']['path']))==manifest['ownerNativeApproval']['sha256']
assert sha(Path(manifest['sourceEquivalence']['path']))==manifest['sourceEquivalence']['sha256']
for c in manifest['captures'].values():assert sha(ROOT/c['path'])==c['sha256'],c['id']


def dashed(d,points,fill,width,dash=35,gap=25):
 carry=0
 for a,b in zip(points,points[1:]):
  dx,dy=b[0]-a[0],b[1]-a[1];length=math.hypot(dx,dy)
  if not length:continue
  pos=0
  while pos<length:
   phase=(carry+pos)%(dash+gap);segment=min(length-pos, (dash if phase<dash else dash+gap)-phase)
   if phase<dash:
    d.line((a[0]+dx*pos/length,a[1]+dy*pos/length,a[0]+dx*(pos+segment)/length,a[1]+dy*(pos+segment)/length),fill=fill,width=width)
   pos+=max(segment,.01)
  carry+=length


def bezier(points,n=100):
 a,b,c,d=points
 return [(int((1-t)**3*a[0]+3*(1-t)**2*t*b[0]+3*(1-t)*t*t*c[0]+t**3*d[0]),int((1-t)**3*a[1]+3*(1-t)**2*t*b[1]+3*(1-t)*t*t*c[1]+t**3*d[1])) for t in [i/n for i in range(n+1)]]


def checks(d,box,size,colors):
 x,y,w,h=box
 for row in range(math.ceil(h/size)):
  for col in range(math.ceil(w/size)):
   d.rectangle((x+col*size,y+row*size,x+(col+1)*size,y+(row+1)*size),fill=colors[(row+col)%2])


def background(kind,W,H):
 scale=W/2752
 palettes={'asphalt':('#111922','#24303b','#f9ce16'),'track-yellow':('#f8c810','#edb30e','#171b23'),'pit-red':('#92272c','#6c2029','#fff5ee'),'steel-blue':('#244c62','#1b3d53','#f4f8fb')}
 base,ink,accent=palettes[kind];im=Image.new('RGB',(W,H),base);d=ImageDraw.Draw(im)
 if kind=='asphalt':
  rng=random.Random(447)
  for _ in range(19000):
   x=rng.randrange(W);y=rng.randrange(H);v=rng.randrange(24,35);d.point((x,y),fill=(v,v+7,v+13))
  pts=bezier([(-W*.2,H*.9),(W*.2,H*.60),(W*.74,H*1.08),(W*1.15,H*.58)])
  d.line(pts,fill=ink,width=int(340*scale))
  dashed(d,pts,(57,67,78),int(8*scale),int(62*scale),int(55*scale))
  d.line((int(W*.02),int(H*.26),int(W*.17),int(H*.26)),fill=accent,width=int(13*scale))
  d.line((int(W*.83),int(H*.26),int(W*.98),int(H*.26)),fill=accent,width=int(13*scale))
 elif kind=='track-yellow':
  for offset,color,width in [(0,'#eda719',170),(.055,'#efb014',34)]:
   pts=bezier([(-W*.25,H*.75),(W*.32,-H*.18),(W*.77,H*1.45),(W*1.13,H*.49+H*offset)])
   d.line(pts,fill=color,width=int(width*scale))
  checks(d,(0,H-int(96*scale),int(W*.19),int(96*scale)),int(48*scale),('#131d26','#f8c810'))
  checks(d,(int(W*.81),H-int(96*scale),W-int(W*.81),int(96*scale)),int(48*scale),('#131d26','#f8c810'))
 elif kind=='pit-red':
  stripe=int(150*scale)
  for x in range(-W,W*2,stripe*2):
   d.polygon([(x,H),(x+stripe,H),(x+H*.25,H*.63),(x+H*.25-stripe,H*.63)],fill=ink)
  d.polygon([(0,H*.91),(W,H*.79),(W,H),(0,H)],fill='#251d28')
  d.line((0,int(H*.91),W,int(H*.79)),fill='#edaf1e',width=int(17*scale))
  for side in [0,1]:
   x=int(W*.038) if side==0 else int(W*.91)
   checks(d,(x,int(H*.035),int(W*.05),int(H*.062)),max(12,int(35*scale)),('#e4bdbb','#92272c'))
 elif kind=='steel-blue':
  spacing=int(92*scale)
  for x in range(0,W,spacing):d.line((x,0,x,H),fill='#2c5368',width=1)
  for y in range(0,H,spacing):d.line((0,y,W,y),fill='#2c5368',width=1)
  pts=bezier([(-W*.1,H*.8),(W*.19,H*.48),(W*.7,H*1.28),(W*1.1,H*.68)])
  d.line(pts,fill='#416377',width=int(65*scale));d.line(pts,fill='#244c62',width=int(51*scale))
  dashed(d,pts,'#426b7f',int(4*scale),int(38*scale),int(28*scale))
  for x,y in [(W*.05,H*.28),(W*.95,H*.28),(W*.05,H*.94),(W*.95,H*.94)]:
   s=int(20*scale);d.line((int(x)-s,int(y),int(x)+s,int(y)),fill='#648297',width=3);d.line((int(x),int(y)-s,int(x),int(y)+s),fill='#648297',width=3)
 return im.convert('RGBA'),accent


def title(canvas,text,kind,accent,W,H):
 d=ImageDraw.Draw(canvas)
 size=int(W*.057)
 while True:
  font=ImageFont.truetype(str(FONT),size,index=8);box=d.textbbox((0,0),text,font=font)
  if box[2]-box[0]<=W*.90:break
  size-=1
 x=(W-(box[2]-box[0]))/2-box[0];y=H*.086-box[1]
 color='#131923' if kind=='track-yellow' else '#ffffff'
 d.text((x,y),text,font=font,fill=color)
 small=ImageFont.truetype(str(FONT),int(W*.0168),index=0)
 brand='HOT WHEELS VS HUMANS';bb=d.textbbox((0,0),brand,font=small)
 d.text(((W-(bb[2]-bb[0]))/2-bb[0],H*.032-bb[1]),brand,font=small,fill=accent)
 return {'headline':[round(x+box[0],2),round(y+box[1],2),box[2]-box[0],box[3]-box[1]],'fontSize':size,'fontName':font.getname(),'centered':True}


def pose(platform,scene,role,W,H):
 count=scene['captureCount'];special=scene['id']=='keep-your-finish' and platform=='ipad'
 if role=='hero':
  if special:return {'cx':W*.5,'top':H*.275,'height':H*.685,'angle':0}
  width=W*(.73 if platform=='ipad' else .74) if count==1 else W*(.65 if platform=='ipad' else .67)
  top=H*.215 if count==1 else H*(.315 if platform=='ipad' else .28)
  return {'cx':W*.5,'top':top,'width':width,'angle':0}
 return {'cx':W*(.18 if role=='left' else .82),'cy':H*(.63 if platform=='ipad' else .605),'width':W*(.54 if not special else .61),'angle':-11 if role=='left' else 11}


def card(canvas,capture,placement,W,H):
 source=ImageOps.exif_transpose(Image.open(ROOT/capture['path'])).convert('RGB')
 if 'width' in placement:w=int(placement['width']);h=round(w*source.height/source.width)
 else:h=int(placement['height']);w=round(h*source.width/source.height)
 image=source.resize((w,h),Image.Resampling.LANCZOS)
 pad=max(10,int(W*.008));frame=Image.new('RGBA',(w+pad*2,h+pad*2),(0,0,0,0));d=ImageDraw.Draw(frame)
 d.rounded_rectangle((0,0,frame.width-1,frame.height-1),radius=max(12,int(W*.01)),fill='#10151d',outline='#56616b',width=max(2,int(W*.001)))
 # Source rectangle remains complete. Only the outer added bezel is rounded.
 frame.paste(image,(pad,pad))
 angle=placement['angle'];frame=frame.rotate(-angle,Image.Resampling.BICUBIC,expand=True)
 cx=placement['cx'];cy=placement.get('cy',placement.get('top',0)+frame.height/2)
 x=round(cx-frame.width/2);y=round(cy-frame.height/2)
 shadow=Image.new('RGBA',canvas.size,(0,0,0,0));mask=frame.getchannel('A');shadow.paste((0,0,0,100),(x+int(W*.002),y+int(W*.012),x+int(W*.002)+frame.width,y+int(W*.012)+frame.height),mask)
 shadow=shadow.filter(ImageFilter.GaussianBlur(W*.008));canvas.alpha_composite(shadow);canvas.alpha_composite(frame,(x,y))
 return {'id':capture['id'],'sourceSHA256':capture['sha256'],'kind':capture['kind'],'role':'hero' if angle==0 else 'left' if angle<0 else 'right','visualRotationDegrees':angle,'bounds':[x,y,frame.width,frame.height],'uprightSourceSize':list(source.size),'resizedNativeSize':[w,h],'fullNativeRectanglePreserved':True,'addedFramePadding':pad,'centerX':cx,'originalEXIF':capture['exifOrientation'],'originalBytesUnchanged':sha(ROOT/capture['path'])==capture['sha256']}

outputs=[]
for platform,settings in manifest['platforms'].items():
 W,H=settings['width'],settings['height'];(ROOT/'exports'/platform).mkdir(parents=True,exist_ok=True)
 assert len(manifest['scenes'])==10 and sum(s['captureCount']>1 for s in manifest['scenes'])==7
 for i,scene in enumerate(manifest['scenes']):
  if i:assert scene['background']!=manifest['scenes'][i-1]['background']
  captures=scene['captures'][platform]
  if scene['ordinal'] in [2,8] and 'left' in captures:captures['right']=captures.pop('left')
  assert len(captures)==scene['captureCount']
  assert len({manifest['captures'][x]['sha256'] for x in captures.values()})==scene['captureCount']
  canvas,accent=background(scene['background'],W,H);text=title(canvas,scene['headlines'][platform],scene['background'],accent,W,H)
  cards=[]
  for role in ['left','right','hero']:
   if role not in captures:continue
   capture=manifest['captures'][captures[role]]
   assert capture['platform']==platform and capture['marketingEligible']
   cards.append(card(canvas,capture,pose(platform,scene,role,W,H),W,H))
  hero=next(c for c in cards if c['role']=='hero');x,y,w,h=hero['bounds']
  assert abs(x+w/2-W/2)<=1 and hero['visualRotationDegrees']==0
  assert y+h<H*.99 and x>0 and x+w<W and y>text['headline'][1]+text['headline'][3]+H*.035,(platform,scene['id'],hero,text)
  dest=ROOT/'exports'/platform/f'{i+1:02d}-{scene["id"]}.png';canvas.convert('RGB').save(dest,compress_level=7)
  outputs.append({'platform':platform,'ordinal':i+1,'scene':scene['id'],'headline':scene['headlines'][platform],'background':scene['background'],'path':str(dest.relative_to(ROOT)),'sha256':sha(dest),'width':W,'height':H,'mode':'RGB','hasAlpha':False,'captureCount':scene['captureCount'],'distinctSources':len({c['sourceSHA256'] for c in cards}),'captures':cards,'headlineGeometry':text,'panoramaPartner':None,'visualReview':'pending','rootApproval':'pending'})
for c in manifest['captures'].values():assert sha(Path(c['nativeOriginalPath']))==c['sha256']==sha(ROOT/c['path'])
for item in freeze['inputs']:assert sha(REPO/item['path'])==item['sha256'],item['path']
manifest['status']='20images rendered; individual and root visual review pending'
(ROOT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
proof={'renderedAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),'rendererSHA256':sha(Path(__file__)),'manifestSHA256':sha(ROOT/'manifest.json'),'sourceAggregateSHA256':freeze['aggregateSHA256'],'all889NativeInputsBeforeAndAfterMatch':True,'font':{'path':str(FONT),'sha256':sha(FONT),'heavyIndex':8},'all21OriginalAndCopiedNativeSourcesUnchanged':True,'deviceOrNativeBuildActions':[],'networkCalls':0,'outputs':outputs}
(ROOT/'render-proof.json').write_text(json.dumps(proof,indent=2)+'\n')
for platform in ['ipad','tv']:
 ordered=[o for o in outputs if o['platform']==platform]
 for batch in range(2):
  group=ordered[batch*5:(batch+1)*5];cellW=980;cellH=round(cellW*settings['height']/settings['width'])
  ratio=(2064/2752) if platform=='ipad' else (2160/3840);cellH=round(cellW*ratio);sheet=Image.new('RGB',(2020,(cellH+70)*3+30),'#eef1f4');d=ImageDraw.Draw(sheet);font=ImageFont.truetype(str(FONT),29,index=0)
  for j,o in enumerate(group):
   x=20+(j%2)*1000;y=20+(j//2)*(cellH+70);d.text((x,y),f'{o["ordinal"]:02d}  {o["headline"]}',font=font,fill='#182430');thumb=Image.open(ROOT/o['path']).resize((cellW,cellH),Image.Resampling.LANCZOS);sheet.paste(thumb,(x,y+48))
  dest=ROOT/'root-review'/f'{platform}-01-05.jpg' if batch==0 else ROOT/'root-review'/f'{platform}-06-10.jpg';dest.parent.mkdir(exist_ok=True);sheet.save(dest,quality=91)
print(json.dumps({'images':len(outputs),'exports':str(ROOT/'exports'),'nativeSourceUnchanged':True}))
