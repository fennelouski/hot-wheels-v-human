from pathlib import Path
import importlib.util,json,uuid,traceback,re,plistlib

leaf=Path(__file__).resolve().parent;script=leaf/'execute-verified-release.py'
spec=importlib.util.spec_from_file_location('hwvh_tv_verifier_readonly',script)
v=importlib.util.module_from_spec(spec);spec.loader.exec_module(v)
first=leaf/'executor-archive-tvos-8d16763ac0d149519f29f944600702a8.json';old=json.loads(first.read_text())
v.require(old['commandExitCode']==0 and old['error']=='TV unexpectedly includes iPad-only camera purpose','Unexpected first TV verifier failure')
receipt=leaf/('tvos-existing-archive-reinspection-'+uuid.uuid4().hex+'.json')
record={'startedAtUTC':v.now(),'releaseCommit':v.COMMIT,'operation':'read-only same successful TV archive reinspection','executorSHA256':v.sha(script.read_bytes()),'firstVerifierFailure':str(first),'firstVerifierFailureSHA256':v.sha(first.read_bytes()),'actualNewXcodeCommands':0,'nativeSourceEdits':0,'originalCommandExitCode':0}
code=0
try:
 plan,freeze,settings,state=v.preflight();record['sourceBefore']=state
 step=plan['steps'][1];v.require(step['platform']=='tvos','Wrong platform')
 v.require(old['command']==step['archive']['argv'],'Actual TV command differs from approved argv')
 log=Path(old['log']);v.require(v.sha(log.read_bytes())==old['logSHA256'],'Actual successful archive log changed')
 text=log.read_text(errors='replace');v.require('** ARCHIVE SUCCEEDED **' in text,'Archive success marker missing')
 v.require(not re.search(r'(?:\s-D\s*DEBUG\b|\s-DDEBUG\b|-enable-testing\b)',text),'DEBUG/testability override present')
 app=Path(step['archive']['expectedApp']);archive=app.parents[2]
 historical=Path('/private/tmp/hwvh-tv-control-signed-final-20261003-park5brc/tvos.xcarchive/Products/Applications/Hot Wheels v Human.app/Info.plist')
 actual=plistlib.loads((app/'Info.plist').read_bytes());before=plistlib.loads(historical.read_bytes())
 v.require(actual.get('NSCameraUsageDescription')==before.get('NSCameraUsageDescription')=='','TV purpose is not the same empty generated historical value')
 inspection=v.inspect_app(app,step,freeze,settings,log,False)
 after=v.preflight()[3];v.require(after==state,'Source changed during reinspection')
 record.update({'status':'PASS','sourceAfter':after,'inspection':inspection,'archiveManifest':v.tree(archive),'archiveCommandLog':str(log),'archiveCommandLogSHA256':v.sha(log.read_bytes()),'cameraMetadataReconciliation':{'actualKeyPresent':True,'actualValue':'','historicalKeyPresent':True,'historicalValue':'','historicalInfoPath':str(historical),'historicalInfoSHA256':v.sha(historical.read_bytes()),'classification':'Empty generated key is not a nonempty camera purpose; no TV camera capability/runtime/permission claim. Exact source unchanged; verifier assumption corrected.'}})
except Exception as e:
 code=1;record.update({'status':'FAIL','errorType':type(e).__name__,'error':str(e),'traceback':traceback.format_exc(),'failurePreserved':True})
 try:record['sourceAfterFailure']=v.preflight()[3]
 except Exception as state_error:record['sourceAfterFailureError']=str(state_error)
record['finishedAtUTC']=v.now();v.write_json(receipt,record)
if code==0:v.write_json(leaf/'tvos-archive-verified.json',record)
print(json.dumps({'status':record['status'],'receipt':str(receipt),'receiptSHA256':v.sha(receipt.read_bytes()),'error':record.get('error'),'actualNewXcodeCommands':0,'sourceUnchanged':record.get('sourceAfter')==record.get('sourceBefore'),'compiledEncryptionKeyPresent':record.get('inspection',{}).get('compiledEncryptionKeyPresent'),'compiledEncryptionValue':record.get('inspection',{}).get('compiledEncryptionValue')},indent=2),flush=True)
raise SystemExit(code)
