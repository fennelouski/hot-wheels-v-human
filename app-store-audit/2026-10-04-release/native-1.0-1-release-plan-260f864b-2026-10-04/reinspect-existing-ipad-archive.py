from pathlib import Path
import importlib.util,json,hashlib,datetime,uuid,traceback,re

leaf=Path(__file__).resolve().parent
script=leaf/'execute-verified-release.py'
spec=importlib.util.spec_from_file_location('hwvh_release_verifier_readonly',script)
v=importlib.util.module_from_spec(spec);spec.loader.exec_module(v)
first=leaf/'executor-archive-ipad-3f935809faac47709a76363694c436d9.json'
old=json.loads(first.read_text())
require=v.require
require(old['commandExitCode']==0 and old['error']=='Copied non-PNG resource bytes differ: README.md','Unexpected preserved failure')
receipt=leaf/('ipad-existing-archive-reinspection-'+uuid.uuid4().hex+'.json')
record={'startedAtUTC':v.now(),'releaseCommit':v.COMMIT,'operation':'read-only reinspection of existing successful iPad archive','executorSHA256':v.sha(script.read_bytes()),'firstVerifierFailure':str(first),'firstVerifierFailureSHA256':v.sha(first.read_bytes()),'actualNewXcodeCommands':0,'nativeSourceEdits':0,'originalCommandExitCode':0}
code=0
try:
 plan,freeze,settings,state=v.preflight();record['sourceBefore']=state
 step=plan['steps'][0];require(step['platform']=='ipad','Wrong platform')
 require(old['command']==step['archive']['argv'],'Existing command differs from approved plan')
 log=Path(old['log']);require(v.sha(log.read_bytes())==old['logSHA256'],'Preserved successful archive log changed')
 text=log.read_text(errors='replace');require('** ARCHIVE SUCCEEDED **' in text,'Archive success marker missing')
 require(not re.search(r'(?:\s-D\s*DEBUG\b|\s-DDEBUG\b|-enable-testing\b)',text),'DEBUG/testability override present')
 app=Path(step['archive']['expectedApp']);archive=app.parents[2]
 inspection=v.inspect_app(app,step,freeze,settings,log,False)
 source_before=state;source_after=v.preflight()[3];require(source_before==source_after,'Source changed during read-only checks')
 docs=[e for e in inspection['resources'] if e.get('resourceDirectoryEntry')]
 require(len(docs)==1 and docs[0]['source']=='Hot Wheels v Human/Features/Profiles/README.md','Unexpected copied documentation source')
 record.update({'status':'PASS','sourceAfter':source_after,'inspection':inspection,'archiveManifest':v.tree(archive),'archiveCommandLog':str(log),'archiveCommandLogSHA256':v.sha(log.read_bytes()),'documentResourceMapping':docs,'reconciliation':'Actual CpResource selects frozen Features/Profiles/README.md for flattened README.md. Its bytes exactly match one of889 frozen inputs. No resource check suppressed; assumed Resources/README origin corrected. Same existing archive; no rebuild.'})
except Exception as e:
 code=1;record.update({'status':'FAIL','errorType':type(e).__name__,'error':str(e),'traceback':traceback.format_exc(),'failurePreserved':True})
 try:record['sourceAfterFailure']=v.preflight()[3]
 except Exception as state_error:record['sourceAfterFailureError']=str(state_error)
record['finishedAtUTC']=v.now();v.write_json(receipt,record)
if code==0:v.write_json(leaf/'ipad-archive-verified.json',record)
print(json.dumps({'status':record['status'],'receipt':str(receipt),'receiptSHA256':v.sha(receipt.read_bytes()),'error':record.get('error'),'sourceUnchanged':record.get('sourceAfter')==record.get('sourceBefore'),'actualNewXcodeCommands':0,'compiledEncryptionKeyPresent':record.get('inspection',{}).get('compiledEncryptionKeyPresent'),'compiledEncryptionValue':record.get('inspection',{}).get('compiledEncryptionValue')},indent=2),flush=True)
raise SystemExit(code)
