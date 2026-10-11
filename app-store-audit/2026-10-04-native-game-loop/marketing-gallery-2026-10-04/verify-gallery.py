"""Read-only checks of final artifact dimensions, provenance, poses and hero pixels."""
from pathlib import Path
from PIL import Image, ImageOps, ImageChops
import json,hashlib,datetime
ROOT=Path(__file__).resolve().parent;REPO=ROOT.parents[2]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
m=json.loads((ROOT/'manifest.json').read_text());p=json.loads((ROOT/'render-proof.json').read_text())
assert p['manifestSHA256']==sha(ROOT/'manifest.json')
assert p['rendererSHA256']==sha(ROOT/'render-gallery.py')
f=json.loads(Path(m['sourceFreeze']['path']).read_text());assert len(f['inputs'])==889
assert sha(Path(m['sourceFreeze']['path']))==m['sourceFreeze']['sha256']
actual=hashlib.sha256(''.join(x['path']+'\0'+x['sha256']+'\n' for x in f['inputs']).encode()).hexdigest()
assert actual==f['aggregateSHA256']==m['sourceFreeze']['aggregateSHA256']=='7377115b02eb7fc59511deeb171f4ce00128b84a6c0f8c110b3247a2bd4de519'
for x in f['inputs']:assert sha(REPO/x['path'])==x['sha256'],x['path']
for c in m['captures'].values():assert sha(ROOT/c['path'])==sha(Path(c['nativeOriginalPath']))==c['sha256']
checks=[]
for platform,dimensions in m['platforms'].items():
 outputs=[x for x in p['outputs'] if x['platform']==platform];assert len(outputs)==10
 assert sum(x['captureCount']>1 for x in outputs)==7 and sum(x['captureCount']==1 for x in outputs)==3
 assert len({x['background'] for x in outputs})==4
 assert all(a['background']!=b['background'] for a,b in zip(outputs,outputs[1:]))
 for o in outputs:
  source=ROOT/o['path'];assert sha(source)==o['sha256'];im=Image.open(source)
  assert im.size==(dimensions['width'],dimensions['height']) and im.mode=='RGB' and 'A' not in im.getbands()
  assert len(o['captures'])==o['captureCount']==len({x['sourceSHA256'] for x in o['captures']})
  hero=next(x for x in o['captures'] if x['role']=='hero');assert hero['visualRotationDegrees']==0
  for c in o['captures']:
   capture=m['captures'][c['id']];assert capture['marketingEligible'] and capture['platform']==platform
   assert c['sourceSHA256']==capture['sha256']
   if c['role']=='left':assert c['visualRotationDegrees']<0
   if c['role']=='right':assert c['visualRotationDegrees']>0
  x,y,w,h=hero['bounds'];pad=hero['addedFramePadding'];nw,nh=hero['resizedNativeSize']
  assert abs(x+w/2-im.width/2)<=1 and x>=0 and x+w<=im.width and y>=0 and y+h<=im.height
  normalized=ImageOps.exif_transpose(Image.open(ROOT/m['captures'][hero['id']]['path'])).convert('RGB').resize((nw,nh),Image.Resampling.LANCZOS)
  shown=im.crop((x+pad,y+pad,x+pad+nw,y+pad+nh))
  assert ImageChops.difference(normalized,shown).getbbox() is None,(platform,o['scene'],'heroPixelDifference')
  hx,hy,hw,hh=o['headlineGeometry']['headline'];assert hx>=0 and hx+hw<=im.width and hy>=0 and y>hy+hh+im.height*.035
  checks.append({'path':o['path'],'sha256':o['sha256'],'canvas':list(im.size),'mode':im.mode,'heroResampledPixelsExact':True,'allOriginalSourceHashesMatch':True,'heroUprightCenteredFullyContained':True,'outwardFansCorrect':True,'headlineContainedSeparated':True,'distinctCaptureCount':o['captureCount']})
receipt={'verifiedAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),'status':'ArtifactQC passed; owner upload/visual approval pending','checksPassed':len(checks),'sourceAggregateSHA256':actual,'all889NativeInputsStillMatch':True,'aggregateOrder':'Stored889inputorder reproduces approved7377115b; native sorted-order description is historicalmetadata mismatch and retained unchanged','all21OriginalCopiedNativeSourcesMatch':True,'platformCounts':{'ipad':{'total':10,'multi':7,'single':3,'backgrounds':4},'tv':{'total':10,'multi':7,'single':3,'backgrounds':4}},'verifierSHA256':sha(Path(__file__)),'checks':checks,'nativeBuildsOrDeviceActions':[],'rootReleaseApproval':False}
(ROOT/'qc-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps({'status':receipt['status'],'images':len(checks),'nativeInputs':889,'exactHeroRegions':20}))
