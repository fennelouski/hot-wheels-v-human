from pathlib import Path
import importlib.util,json,traceback,uuid,plistlib

leaf=Path(__file__).resolve().parent
script=leaf/'execute-verified-release.py'
spec=importlib.util.spec_from_file_location('hwvh_upload_reconciliation',script)
v=importlib.util.module_from_spec(spec);spec.loader.exec_module(v)
first=leaf/'executor-upload-ipad-94ff5413d2f1433da59ecf3225498a0b.json'
old=json.loads(first.read_text())
v.require(old['commandExitCode']==0 and old['error']=='Archive bytes changed after upload','Unexpected first upload verifier failure')
receipt=leaf/('ipad-existing-upload-reconciliation-'+uuid.uuid4().hex+'.json')
record={'startedAtUTC':v.now(),'releaseCommit':v.COMMIT,'operation':'read-only reconciliation of already successful iPad upload','executorSHA256':v.sha(script.read_bytes()),'firstVerifierFailure':str(first),'firstVerifierFailureSHA256':v.sha(first.read_bytes()),'actualNewXcodeCommands':0,'uploadRepeated':False,'nativeSourceEdits':0,'commandExitCode':0}
code=0
try:
 plan,freeze,settings,state=v.preflight();record['sourceBefore']=state
 step=plan['steps'][0];earlier=v.load_stage('ipad','local-export')
 v.require(old['command']==step['uploadOnlyAfterAllChecksAndRootAllocation']['argv'],'Existing successful upload differs from approved argv')
 log=Path(old['log']);v.require(v.sha(log.read_bytes())==old['logSHA256'],'Original upload log changed')
 text=log.read_text(errors='replace')
 v.require('** EXPORT SUCCEEDED **' in text and 'Upload succeeded' in text,'Actual delivery-success markers missing')
 archive=Path(step['archive']['expectedApp']).parents[2]
 classification=v.classify_archive_after_upload(archive,earlier['archiveManifest'])
 v.require(v.sha(Path(earlier['IPA']).read_bytes())==earlier['IPASHA256'],'Verified local IPA changed')
 v.require(v.tree(Path(earlier['inspection']['app']))==earlier['inspection']['bundleManifest'],'Verified distribution bundle changed')
 metadata=plistlib.loads((archive/'Info.plist').read_bytes());metadata.pop('Distributions')
 reconstructed=plistlib.dumps(metadata,fmt=plistlib.FMT_XML,sort_keys=True)
 v.require(v.sha(reconstructed)==classification['reconstructedOriginalSHA256'],'Reconstruction bytes mismatch')
 baseline_copy=leaf/'ipad-archive-root-info.reconstructed-before-upload.plist'
 with baseline_copy.open('xb') as f:f.write(reconstructed)
 current_copy=leaf/'ipad-archive-root-info.after-upload.plist'
 with current_copy.open('xb') as f:f.write((archive/'Info.plist').read_bytes())
 after=v.preflight()[3];v.require(state==after,'Source changed during reconciliation')
 record.update({'status':'PASS','sourceAfter':after,'archiveUnchanged':False,'archivePayloadUnchanged':True,'archivePostUploadClassification':classification,'verifiedIPAAndDistributionAppUnchanged':True,'originalArchiveMetadataBytesReconstructedAndSHAEqualsRecordedBaseline':True,'initialDecodedArchiveRootBaselineWasNotCaptured':True,'reconstructedBaselineCopy':str(baseline_copy),'reconstructedBaselineCopySHA256':v.sha(baseline_copy.read_bytes()),'postUploadArchiveMetadataCopy':str(current_copy),'postUploadArchiveMetadataCopySHA256':v.sha(current_copy.read_bytes()),'deliveryRecord':v.genuine_delivery_record(log),'uploadSucceededObserved':True,'processingMessageObserved':'Uploaded package is processing' in text,'originalUploadLog':str(log),'originalUploadLogSHA256':v.sha(log.read_bytes()),'submissionClaimed':False,'rightsStatus':'Root separately holds final content-rights/submission declaration pending72ElevenLabs WAV generation-license evidence; upload approval remains explicit, no rights answer made here','AppleFollowUp':'Fresh processed-build/gallery selection and actual submission remain root-owned; physicalLAN/camera limitations retained'})
except Exception as e:
 code=1;record.update({'status':'FAIL','errorType':type(e).__name__,'error':str(e),'traceback':traceback.format_exc(),'failurePreserved':True})
 try:record['sourceAfterFailure']=v.preflight()[3]
 except Exception as state_error:record['sourceAfterFailureError']=str(state_error)
record['finishedAtUTC']=v.now();v.write_json(receipt,record)
if code==0:v.write_json(leaf/'ipad-upload-verified.json',record)
print(json.dumps({'status':record['status'],'receipt':str(receipt),'receiptSHA256':v.sha(receipt.read_bytes()),'error':record.get('error'),'actualNewXcodeCommands':0,'uploadRepeated':False,'allArchiveAppDSYMsOtherFilesAndIPAUnchanged':record.get('archivePayloadUnchanged') and record.get('verifiedIPAAndDistributionAppUnchanged'),'deliveryUUID':record.get('deliveryRecord',{}).get('deliveryUUID'),'sourceUnchanged':record.get('sourceAfter')==record.get('sourceBefore')},indent=2),flush=True)
raise SystemExit(code)
