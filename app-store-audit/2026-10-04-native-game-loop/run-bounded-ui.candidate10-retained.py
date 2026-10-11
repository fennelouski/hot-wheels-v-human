#!/usr/bin/env python3
"""Authorized single TV Share or three isolated Pad flows; never opens Simulator.app."""
import datetime,hashlib,json,pathlib,subprocess,sys,traceback
root=pathlib.Path(__file__).resolve().parents[2];audit=pathlib.Path(__file__).parent
platform,candidate,tag=sys.argv[1:]
assert platform in ['tv','ipad'];assert candidate.isdigit();assert tag.replace('-','').isalnum()
udid={'tv':'BF090DFE-C6F6-4FF4-AB70-8870241B497E','ipad':'025B233C-9EE8-48DD-A4E8-BB88CF93F0DE'}[platform]
sourcePath=audit/f'native-inputs.candidate-{candidate}.json'; compiledPath=audit/f'compiled-artifacts.candidate-{candidate}.json'
source=json.loads(sourcePath.read_text());compiled=json.loads(compiledPath.read_text())
artifacts=next(p['artifacts'] for p in compiled['platforms'] if p['platform']==platform)
assert compiled['sourceAggregateSHA256']==source['aggregateSHA256']
def now():return datetime.datetime.now(datetime.timezone.utc).isoformat()
def guard():
 bad=[i['path'] for i in source['inputs'] if hashlib.sha256((root/i['path']).read_bytes()).hexdigest()!=i['sha256']]
 bad +=[i['path'] for i in artifacts if hashlib.sha256(pathlib.Path(i['path']).read_bytes()).hexdigest()!=i['sha256']]
 assert not bad,bad

def device():
 d=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','available','--json']))
 return next(i for group in d['devices'].values() for i in group if i['udid']==udid)
def appearance():
 r=subprocess.run(['xcrun','simctl','ui',udid,'appearance'],capture_output=True,text=True)
 return {'exitCode':r.returncode,'stdout':r.stdout,'stderr':r.stderr}
def snapshot(name):
 p=audit/f'{platform}-normal-stores.{name}-candidate{candidate}.json'
 subprocess.run([sys.executable,str(audit/'snapshot-normal-stores.py'),udid,str(p)],check=True)
 return json.loads(p.read_text())
base=f'{platform}-candidate{candidate}-{tag}';receipt={'startedAt':now(),'sourceProof':sourcePath.name,'compiledProof':compiledPath.name,'udid':udid}
receiptPath=audit/f'{platform}-runtime-candidate{candidate}-{tag}.json'
try:
 guard(); pre=device();assert pre['state']=='Shutdown',pre['state'];assert pathlib.Path(pre['dataPath']).is_dir()
 receipt['preflightDevice']={k:pre[k] for k in ['udid','state','name','deviceTypeIdentifier','dataPath']}
 before=snapshot('before-'+tag)
 subprocess.run(['xcrun','simctl','boot',udid],check=True)
 subprocess.run(['xcrun','simctl','bootstatus',udid,'-b'],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.STDOUT)
 receipt['appearanceBefore']=appearance()
 if platform=='ipad':assert receipt['appearanceBefore']['stdout'].strip()=='light'
 guard()
 xctestrun=next(i['path'] for i in artifacts if i['path'].endswith('.xctestrun'))
 methods=['testFirstViewportPlayActualFinishShareAndRematch()'] if platform=='tv' else ['testFirstViewportPlayActualFinishShareAndRematch()','testIndependentSavedSettingsAndCalmPlay()','testOptionalProfileStillOpensEveryWorkshop()']
 expected=['Hot Wheels v HumanUITests/GameLoopUITests/'+m for m in methods]
 cmd=['xcodebuild','test-without-building','-xctestrun',xctestrun,'-destination',('platform=tvOS Simulator,id=' if platform=='tv' else 'platform=iOS Simulator,id=')+udid,'-parallel-testing-enabled','NO']
 cmd+=['-only-testing:'+i for i in expected]
 enum=audit/(base+'-enumeration.json')
 with (audit/(base+'-enumeration.log')).open('w') as f:
  r=subprocess.run(cmd+['-enumerate-tests','-test-enumeration-style','flat','-test-enumeration-format','json','-test-enumeration-output-path',str(enum)],stdout=f,stderr=subprocess.STDOUT)
 assert r.returncode==0,r.returncode
 j=json.loads(enum.read_text()); enabled=[i['identifier'] for v in j['values'] for i in v.get('enabledTests',[])]
 assert sorted(enabled)==sorted(expected),(enabled,expected)
 receipt['enumeratedTests']=enabled;guard()
 result='/tmp/hwvh-game-loop-'+base+'-20261004.xcresult';assert not pathlib.Path(result).exists()
 cmd+=['-resultBundlePath',result];log=audit/(base+'.log');receipt['command']=cmd
 with log.open('w') as f:r=subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT)
 receipt.update(exitCode=r.returncode,resultBundle=result,log=log.name,logSHA256=hashlib.sha256(log.read_bytes()).hexdigest())
 print('test exit',r.returncode,flush=True)
except BaseException as e:
 receipt['wrapperFailure']=repr(e);traceback.print_exc()
finally:
 receipt['appearanceAfter']=appearance()
 r=subprocess.run(['xcrun','simctl','shutdown',udid],capture_output=True,text=True)
 receipt['shutdownExitCode']=r.returncode;receipt['finalDeviceState']=device()['state']
 try:
  after=snapshot('after-'+tag);receipt['normalFilesUnchanged']=before['normalFiles']==after['normalFiles']
  guard();receipt['nativeAndCompiledHashesUnchanged']=True
 except BaseException as e:receipt['guardFailure']=repr(e)
 receipt['appearanceUnchanged']=receipt.get('appearanceBefore')==receipt['appearanceAfter']
 receipt['finishedAt']=now();receiptPath.write_text(json.dumps(receipt,indent=2)+'\n')
 print(json.dumps({k:receipt.get(k) for k in ['exitCode','wrapperFailure','finalDeviceState','normalFilesUnchanged','nativeAndCompiledHashesUnchanged','appearanceUnchanged']}),flush=True)
if receipt.get('wrapperFailure') or receipt.get('guardFailure') or receipt.get('exitCode')!=0 or not receipt.get('normalFilesUnchanged') or not receipt.get('nativeAndCompiledHashesUnchanged') or receipt['finalDeviceState']!='Shutdown':raise SystemExit(1)
