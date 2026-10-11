#!/usr/bin/env python3
"""Audit-owned, allocation-gated release executor; default mode is preflight only.

No app/source changes. Call one operation at a time after a direct root allocation.
The approved plan is immutable. A failed command/check gets its own UUID receipt.
"""
from pathlib import Path
import argparse, datetime, fcntl, fnmatch, hashlib, json, os, plistlib, re, shlex
import subprocess, sys, traceback, uuid

LEAF = Path(__file__).resolve().parent
PLAN = LEAF/'ipad-tvos-1.0-1-release-plan.260f864b.json'
PLAN_SHA = '96ddeef5a126025d18555216b04f0a37a5e03262d70f32b6cad6265943b9d3d6'
COMMIT = '260f864b143b16f49418e5b8f8d35a6a9849c6bf'
REPO = Path('/Users/nathan/Documents/GitHub/hot-wheels-v-human')
EXPECTED_AGGREGATE = '7377115b02eb7fc59511deeb171f4ce00128b84a6c0f8c110b3247a2bd4de519'

def sha(data): return hashlib.sha256(data).hexdigest()
def now(): return datetime.datetime.now(datetime.timezone.utc).isoformat()
def require(condition, message):
    if not condition: raise RuntimeError(message)
def output(argv): return subprocess.check_output(argv, cwd=REPO, stderr=subprocess.PIPE)
def git(*args): return output(['git', *args])
def write_json(path, data):
    with path.open('x') as f: f.write(json.dumps(data, indent=2)+'\n')
def tree(root):
    entries=[]
    for p in sorted(root.rglob('*')):
        if p.is_symlink():
            entries.append({'path':str(p.relative_to(root)), 'symlink':os.readlink(p)})
        elif p.is_file():
            b=p.read_bytes();entries.append({'path':str(p.relative_to(root)), 'bytes':len(b), 'sha256':sha(b)})
    require(bool(entries), 'Artifact tree is empty')
    return {'fileCount':len(entries), 'aggregateSHA256':sha(json.dumps(entries,sort_keys=True,separators=(',',':')).encode()), 'files':entries}

def preflight():
    require(sha(PLAN.read_bytes())==PLAN_SHA, 'Approved release plan bytes changed')
    plan=json.loads(PLAN.read_text())
    require(git('rev-parse','HEAD').decode().strip()==COMMIT, 'HEAD differs from approved release commit')
    require(not git('diff','--cached','--name-only','-z'), 'Git index is not empty')
    freeze_path=Path(plan['inputFreeze'])
    require(sha(freeze_path.read_bytes())==plan['inputFreezeSHA256'], 'Original freeze receipt changed')
    freeze=json.loads(freeze_path.read_text())
    require(len(freeze['inputs'])==freeze['inputCount']==889, 'Native input count changed')
    for e in freeze['inputs']:
        b=(REPO/e['path']).read_bytes()
        require(sha(b)==e['sha256'] and len(b)==e['bytes'], 'Frozen native input changed: '+e['path'])
    aggregate=sha(''.join(e['path']+'\0'+e['sha256']+'\n' for e in freeze['inputs']).encode())
    require(aggregate==freeze['aggregateSHA256']==EXPECTED_AGGREGATE, 'Recorded-order source aggregate changed')
    cpath=Path(plan['localCommitReceipt'])
    require(sha(cpath.read_bytes())==plan['localCommitReceiptSHA256'], 'Local commit receipt changed')
    committed=json.loads(cpath.read_text())
    require(committed['localCommit']==COMMIT and len(committed['committedBlobs'])==40, 'Native commit identity changed')
    for e in committed['committedBlobs']:
        require(sha(git('show', COMMIT+':'+e['path']))==e['sha256']==sha((REPO/e['path']).read_bytes()), 'Committed native blob mismatch')
    for e in plan['staticNativeEvidence']:
        require(sha(Path(e['path']).read_bytes())==e['sha256'], 'Static release input changed')
    for key,hashkey in [('freshExactUploadCopy','freshExactUploadCopySHA256'),('localExportOptions','localExportOptionsSHA256')]:
        require(sha(Path(plan['exportOptions'][key]).read_bytes())==plan['exportOptions'][hashkey], 'Approved export options changed')
    upload=plistlib.loads(Path(plan['exportOptions']['freshExactUploadCopy']).read_bytes())
    local=plistlib.loads(Path(plan['exportOptions']['localExportOptions']).read_bytes())
    require(local=={**upload,'destination':'export'} and upload['manageAppVersionAndBuildNumber'] is False, 'Unexpected export option/version change')
    p=REPO/'Hot Wheels v Human.xcodeproj/project.pbxproj'
    obj=json.loads(output(['plutil','-convert','json','-o','-',str(p)]))
    target=next(o for o in obj['objects'].values() if o.get('isa')=='PBXNativeTarget' and o.get('name')=='Hot Wheels v Human')
    settings=next(obj['objects'][c] for c in obj['objects'][target['buildConfigurationList']]['buildConfigurations'] if obj['objects'][c]['name']=='Release')['buildSettings']
    require(settings['MARKETING_VERSION']=='1.0' and settings['CURRENT_PROJECT_VERSION']=='1', 'App version/build changed')
    require(settings['DEVELOPMENT_TEAM']==upload['teamID'], 'Project and held signing option teams differ')
    return plan,freeze,settings,{'commit':COMMIT,'version':'1.0','build':'1','inputCount':889,'aggregateSHA256':aggregate,'sourceBytesMatch':True,'indexEmpty':True}

def allocated(args, plan):
    require(args.allocation_receipt is not None, 'No direct root serialized-slot allocation receipt supplied; Xcode execution blocked')
    path=Path(args.allocation_receipt)
    allocation=json.loads(path.read_text())
    require(allocation.get('allocatedBy')=='/root' and allocation.get('serializedSlotAllocated') is True, 'Root slot is not allocated')
    require(allocation.get('releaseCommit')==COMMIT and allocation.get('releasePlanSHA256')==PLAN_SHA, 'Allocation candidate differs')
    require(args.operation in allocation.get('allowedOperations',[]) and args.platform in allocation.get('allowedPlatforms',[]), 'Operation/platform outside allocation')
    allocated_at=datetime.datetime.fromisoformat(allocation['allocatedAtUTC'])
    age=(datetime.datetime.now(datetime.timezone.utc)-allocated_at).total_seconds()
    require(0<=age<=8*3600, 'Allocation receipt is stale or future-dated')
    # A read-only process check catches accidental conflicting host commands.
    processes=output(['ps','-axo','pid=,comm=']).decode().splitlines()
    require(not [p for p in processes if p.split() and Path(p.split()[-1]).name=='xcodebuild'], 'Another xcodebuild currently owns the host')
    return {'path':str(path),'sha256':sha(path.read_bytes()),'directRootSlotAllocated':True}

def load_stage(platform, stage):
    p=LEAF/(platform+'-'+stage+'-verified.json')
    value=json.loads(p.read_text())
    require(value['releaseCommit']==COMMIT and value['status']=='PASS', 'Required earlier stage did not pass')
    return value

def classify_archive_after_upload(archive, before):
    after=tree(archive)
    if after==before:
        return {'archiveFullyByteIdentical':True,'archiveAppDSYMsAndAllOtherFilesUnchanged':True,'afterManifest':after,'changedFiles':[]}
    original={e['path']:e for e in before['files']}
    current={e['path']:e for e in after['files']}
    require(set(original)==set(current), 'Upload changed archive file set')
    changed=[p for p in original if original[p]!=current[p]]
    require(changed==['Info.plist'], 'Upload changed shipped app/dSYMs or unexpected archive files')
    metadata_path=archive/'Info.plist'
    metadata=plistlib.loads(metadata_path.read_bytes())
    history=metadata.get('Distributions')
    require(isinstance(history,list) and bool(history), 'Changed archive-root metadata lacks Xcode distribution history')
    # Initial decoded root metadata was not captured. Reconstruct bytes after
    # removing this new history and REQUIRE the recorded original full-byte SHA.
    # Matching that cryptographic baseline proves every remaining field/byte.
    without_history={k:value for k,value in metadata.items() if k!='Distributions'}
    reconstruction=None
    for fmt in [plistlib.FMT_XML,plistlib.FMT_BINARY]:
        for sort in [True,False]:
            candidate=plistlib.dumps(without_history,fmt=fmt,sort_keys=sort)
            if sha(candidate)==original['Info.plist']['sha256']:
                reconstruction=candidate;break
        if reconstruction is not None: break
    require(reconstruction is not None, 'Archive-root change is not solely distribution history by exact original hash; investigate')
    last=history[-1]
    require(last.get('uploadEvent',{}).get('state')=='success' and str(last.get('uploadedBuildNumber'))=='1', 'Archive distribution history does not record this successful build1 upload')
    require(str(last.get('adamId'))=='6818777508', 'Archive upload history refers to another app')
    return {'archiveFullyByteIdentical':False,'archiveAppDSYMsAndAllOtherFilesUnchanged':True,'changedFiles':changed,'beforeRootInfo':original['Info.plist'],'afterRootInfo':current['Info.plist'],'originalDecodedBaselineCapturedInitially':False,'originalBytesReconstructedByRemovingDistributions':True,'reconstructedOriginalSHA256':sha(reconstruction),'remainingOriginalMetadataExactByteHashVerified':True,'metadataDelta':'Xcode added Distributions success history at archive root; shipped app/dSYMs/resources unchanged','distributionIdentifier':last.get('identifier'),'uploadEventState':last['uploadEvent']['state'],'uploadedBuildNumber':str(last['uploadedBuildNumber']),'afterManifest':after}

def genuine_delivery_record(log):
    candidates=re.findall(r'"([^"\n]+\.xcdistributionlogs)"',log.read_text(errors='replace'))
    for path in reversed(candidates):
        directory=Path(path);content=directory/'ContentDelivery.log'
        if not content.is_file(): continue
        text=content.read_text(errors='replace')
        match=re.search(r'Delivery UUID[^\n]*?\b([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\b',text,re.I)
        if match:
            return {'deliveryUUID':match.group(1),'sourceLabel':'Delivery UUID in genuine ContentDelivery.log','sourceLog':str(content),'sourceLogSHA256':sha(content.read_bytes()),'distributionLogs':str(directory),'distributionLogFiles':[{'name':p.name,'bytes':p.stat().st_size,'sha256':sha(p.read_bytes())} for p in sorted(directory.iterdir()) if p.is_file()]}
    return {'deliveryUUID':None,'sourceLabel':'No explicit Delivery UUID located in genuine generated distribution logs; no ID invented'}

def run_xcode(command, attempt):
    log=Path(command['stdoutStderrLog'])
    require(not log.exists(), 'Command log exists; preserve first failure and use explicit root-reviewed retry paths')
    log.parent.mkdir(parents=True,exist_ok=True)
    attempt['command']=command['argv'];attempt['log']=str(log);attempt['commandStartedAtUTC']=now()
    print(json.dumps({'event':'starting-approved-command','operation':ARGS.operation,'platform':ARGS.platform,'log':str(log)}),flush=True)
    with log.open('xb') as f:
        result=subprocess.run(command['argv'],cwd=REPO,stdout=f,stderr=subprocess.STDOUT)
    attempt.update({'commandExitCode':result.returncode,'commandFinishedAtUTC':now(),'logSHA256':sha(log.read_bytes())})
    require(result.returncode==0, 'Actual xcodebuild command failed; original log retained')
    return log

def plist_output(argv):
    raw=output(argv)
    start=raw.find(b'<?xml')
    if start>=0: raw=raw[start:raw.find(b'</plist>',start)+8]
    return plistlib.loads(raw)

def permitted(actual, allowed):
    if isinstance(allowed,str) and isinstance(actual,str): return fnmatch.fnmatchcase(actual,allowed)
    if isinstance(actual,list):
        choices=allowed if isinstance(allowed,list) else [allowed]
        return all(any(permitted(x,y) for y in choices) for x in actual)
    return actual==allowed

def dimensions(path):
    value=output(['sips','-g','pixelWidth','-g','pixelHeight',str(path)]).decode()
    width=re.search(r'pixelWidth:\s*(\d+)',value);height=re.search(r'pixelHeight:\s*(\d+)',value)
    require(width and height, 'PNG dimensions unavailable')
    return [int(width.group(1)),int(height.group(1))]

def inspect_app(app, step, freeze, settings, archive_log, distribution):
    require(app.is_dir(), 'Expected app bundle is missing')
    info=plistlib.loads((app/'Info.plist').read_bytes())
    require(info['CFBundleShortVersionString']=='1.0' and str(info['CFBundleVersion'])=='1', 'Compiled app is not exact1.0(1)')
    require(info['CFBundleIdentifier']==settings['PRODUCT_BUNDLE_IDENTIFIER'] and info.get('CFBundleDisplayName')=='HWvH', 'Compiled identity differs')
    require(info['UIDeviceFamily']==step['expectedDeviceFamilies'] and info['MinimumOSVersion']=='26.0', 'Compiled families or deployment floor differ')
    platform_name='iPhoneOS' if step['platform']=='ipad' else 'AppleTVOS'
    require(info['CFBundleSupportedPlatforms']==[platform_name] and info['DTPlatformName']==step['SDK'], 'Compiled platform expansion/mismatch')
    executable=app/info['CFBundleExecutable']
    require(output(['lipo','-archs',str(executable)]).decode().strip()=='arm64', 'Unexpected executable architectures')
    source_info=plistlib.loads((REPO/'Hot Wheels v Human/Info.plist').read_bytes())
    require('ITSAppUsesNonExemptEncryption' in info and info['ITSAppUsesNonExemptEncryption'] is source_info['ITSAppUsesNonExemptEncryption'] is False, 'Actual compiled encryption key missing/different; no legal/source correction inferred')
    for key in ['NSLocalNetworkUsageDescription','NSBonjourServices']:
        require(info.get(key)==source_info[key], 'Compiled local-network declaration differs')
    camera=settings['INFOPLIST_KEY_NSCameraUsageDescription[sdk=iphoneos*]']
    if step['platform']=='ipad': require(info.get('NSCameraUsageDescription')==camera, 'Compiled camera purpose differs')
    else: require(info.get('NSCameraUsageDescription') in (None,''), 'TV unexpectedly includes a nonempty iPad-only camera purpose')
    privacy_path=app/'PrivacyInfo.xcprivacy'
    require(privacy_path.read_bytes()==(REPO/'Hot Wheels v Human/PrivacyInfo.xcprivacy').read_bytes(), 'Compiled privacy manifest differs from frozen source')
    output(['codesign','--verify','--deep','--strict','--verbose=2',str(app)])
    sign=subprocess.run(['codesign','-d','--verbose=4',str(app)],capture_output=True,check=True).stderr.decode()
    signed_team=re.search(r'^TeamIdentifier=(.+)$',sign,re.M)
    require(signed_team and signed_team.group(1)==settings['DEVELOPMENT_TEAM'], 'Actual signed team mismatches project')
    require('Authority=Apple Root CA' in sign, 'Signature is not rooted in expected Apple authority')
    ent=plist_output(['codesign','-d','--entitlements',':-',str(app)])
    profile_path=app/'embedded.mobileprovision'
    profile=plist_output(['security','cms','-D','-i',str(profile_path)])
    team=settings['DEVELOPMENT_TEAM'];appid=team+'.'+settings['PRODUCT_BUNDLE_IDENTIFIER']
    require(profile.get('TeamIdentifier')==[team], 'Provisioning team mismatches project')
    require(ent.get('application-identifier')==appid and ent.get('com.apple.developer.team-identifier')==team, 'Signed identity entitlements mismatch')
    expiry=profile['ExpirationDate'].replace(tzinfo=datetime.timezone.utc)
    require(expiry>datetime.datetime.now(datetime.timezone.utc), 'Provisioning profile expired')
    require(('iOS' if step['platform']=='ipad' else 'tvOS') in profile['Platform'], 'Provisioning profile lacks intended platform')
    allowed_keys={'application-identifier','com.apple.developer.team-identifier','get-task-allow','beta-reports-active','keychain-access-groups'}
    require(set(ent)<=allowed_keys, 'Unexpected signed capability outside current empty source entitlements; root review required')
    for key,value in ent.items():
        require(key in profile['Entitlements'] and permitted(value,profile['Entitlements'][key]), 'App entitlement is outside actual profile allowance: '+key)
    distribution_signed='Authority=Apple Distribution' in sign
    if distribution:
        require(distribution_signed and ent.get('get-task-allow') is False and profile['Entitlements'].get('get-task-allow') is False, 'Distribution export is not App Store signed/no-debug')
        require('ProvisionedDevices' not in profile and not profile.get('ProvisionsAllDevices',False), 'Distribution profile is device-list/ad-hoc/enterprise')
    # Source PNGs are deliberately optimized by Xcode. Prove mapping and dimensions,
    # rather than confusing compiled bytes with source identity or claiming pixel QA.
    png_sources={}
    copied_sources={}
    frozen_by_path={entry['path']:entry for entry in freeze['inputs']}
    log_text=archive_log.read_text(errors='replace')
    for line in log_text.splitlines():
        if line.startswith('CopyPNGFile '):
            tokens=shlex.split(line)
            png_sources[Path(tokens[1]).name]=Path(tokens[2])
        elif line.startswith('CpResource '):
            tokens=shlex.split(line)
            copied_sources[Path(tokens[1]).name]=Path(tokens[2])
    resources=[]
    for entry in freeze['inputs']:
        if not entry['path'].startswith('Hot Wheels v Human/Resources/'): continue
        src=REPO/entry['path'];bundled=app/src.name
        require(bundled.is_file(), 'Frozen resource missing: '+src.name)
        record={'source':entry['path'],'sourceSHA256':entry['sha256'],'bundled':src.name,'bundledSHA256':sha(bundled.read_bytes())}
        if src.suffix=='.png':
            require(png_sources.get(src.name)==src, 'Actual CopyPNGFile source mapping differs: '+src.name)
            dims=dimensions(bundled)
            # Pillow reads only the standard frozen source; sips handles Xcode PNGs.
            from PIL import Image
            with Image.open(src) as source_image: source_size=list(source_image.size)
            require(dims==source_size, 'Optimized PNG dimensions differ: '+src.name)
            record.update({'classification':'Xcode CopyPNGFile optimized resource; source mapping/dimensions verified, pixel identity not separately claimed','dimensions':dims})
        elif src.suffix=='.md':
            # File-system synchronized groups compile a single README into the
            # flattened bundle. Require its actual CpResource source and frozen
            # bytes; do not presume Resources/README.md wins that name mapping.
            actual_source=copied_sources.get(src.name)
            require(actual_source is not None, 'Document lacks actual CpResource source mapping')
            actual_relative=str(actual_source.relative_to(REPO))
            actual_input=frozen_by_path.get(actual_relative)
            require(actual_input is not None, 'Actual document resource source is not one of889 frozen inputs')
            require(record['bundledSHA256']==actual_input['sha256']==sha(actual_source.read_bytes()), 'Actual copied document does not match its frozen source')
            record.update({'resourceDirectoryEntry':entry['path'],'source':actual_relative,'sourceSHA256':actual_input['sha256'],'classification':'Byte-identical frozen document selected by actual CpResource mapping; resource-directory README is not the selected flattened document'})
        else:
            require(record['bundledSHA256']==entry['sha256'], 'Copied non-PNG resource bytes differ: '+src.name)
            record['classification']='Byte-identical copied frozen resource'
        resources.append(record)
    require(len(resources)==697, 'Expected frozen resource count changed')
    icons=json.loads(output(['/usr/bin/assetutil','--info',str(app/'Assets.car')]))
    names=[str(x.get('Name','')) for x in icons]
    if step['platform']=='ipad': require(any(x=='AppIcon' for x in names), 'Compiled iPad icon absent')
    else:
        require(any('App Icon' in x for x in names) and 'Top Shelf Image' in names and 'Top Shelf Image Wide' in names, 'TV layered icon/top-shelf renditions absent')
    require(b'-HWTestSession' not in executable.read_bytes() and b'unit-host-' not in executable.read_bytes(), 'DEBUG QA selector strings present in Release executable')
    return {'app':str(app),'signatureValid':True,'distributionSigned':distribution_signed,'getTaskAllow':ent.get('get-task-allow'),'signedTeamMatchesProject':True,'profileTeamMatchesProject':True,'profileExpirationUTC':expiry.isoformat(),'profilePlatform':profile['Platform'],'profileHasProvisionedDevices':'ProvisionedDevices' in profile,'profileProvisionsAllDevices':profile.get('ProvisionsAllDevices',False),'entitlementKeys':sorted(ent),'entitlementsFitProfile':True,'profileSHA256':sha(profile_path.read_bytes()),'info':info,'infoSHA256':sha((app/'Info.plist').read_bytes()),'compiledEncryptionKeyPresent':True,'compiledEncryptionValue':False,'compiledCameraKeyPresent':'NSCameraUsageDescription' in info,'compiledCameraPurpose':info.get('NSCameraUsageDescription'),'executableSHA256':sha(executable.read_bytes()),'architecture':'arm64','privacyManifestSHA256':sha(privacy_path.read_bytes()),'resourceCount':len(resources),'resources':resources,'compiledAssetRenditions':icons,'AssetsCAR_SHA256':sha((app/'Assets.car').read_bytes()),'QASelectorStringsAbsent':True,'bundleManifest':tree(app)}

def main(args, attempt):
    global LOCK_HANDLE
    plan,freeze,settings,source=preflight();attempt['sourceBefore']=source
    if args.operation=='preflight':
        attempt.update({'status':'PASS','execution':'READ-ONLY preflight; no Xcode/device/account operation','buildSlotAllocated':False,'artifactRootExists':Path(plan['immutableArtifactRoot']).exists()})
        return
    attempt['allocation']=allocated(args,plan)
    LOCK_HANDLE=(LEAF/'executor-release-slot.lock').open('a')
    fcntl.flock(LOCK_HANDLE,fcntl.LOCK_EX|fcntl.LOCK_NB)
    # The lock is held through process exit, serializing both platform stages.
    step=next(x for x in plan['steps'] if x['platform']==args.platform)
    archive=Path(step['archive']['argv'][step['archive']['argv'].index('-archivePath')+1])
    if args.operation=='archive':
        require(not archive.exists(), 'Archive already exists; preserve first artifact')
        log=run_xcode(step['archive'],attempt)
        require('** ARCHIVE SUCCEEDED **' in log.read_text(errors='replace'), 'Actual archive-success marker absent')
        text=log.read_text(errors='replace')
        require(not re.search(r'(?:\s-D\s*DEBUG\b|\s-DDEBUG\b|-enable-testing\b)',text), 'DEBUG/testability compiler override present')
        inspection=inspect_app(Path(step['archive']['expectedApp']),step,freeze,settings,log,False)
        attempt.update({'inspection':inspection,'archiveManifest':tree(archive),'status':'PASS'})
    elif args.operation=='local-export':
        earlier=load_stage(args.platform,'archive')
        require(tree(archive)==earlier['archiveManifest'], 'Archive changed before local export')
        require(not Path(step['localDistributionExport']['expectedIPA']).parent.exists(), 'Local export output already exists')
        log=run_xcode(step['localDistributionExport'],attempt)
        require('** EXPORT SUCCEEDED **' in log.read_text(errors='replace'), 'Actual local-export-success marker absent')
        ipa=Path(step['localDistributionExport']['expectedIPA']);unpack=Path(step['localDistributionExport']['inspectionRoot'])
        require(not unpack.exists(), 'Distribution inspection destination already exists')
        output(['ditto','-x','-k',str(ipa),str(unpack)])
        app=unpack/'Payload/Hot Wheels v Human.app'
        inspection=inspect_app(app,step,freeze,settings,Path(step['archive']['stdoutStderrLog']),True)
        previous=earlier['inspection']
        require(inspection['info']==previous['info'], 'Complete decoded archive/export Info.plist differs; investigate rather than suppress')
        before={e['path']:e for e in previous['bundleManifest']['files']}
        after={e['path']:e for e in inspection['bundleManifest']['files']}
        require(set(before)==set(after), 'Archive/export bundle file sets differ')
        permitted_changes={inspection['info']['CFBundleExecutable'],'embedded.mobileprovision','Info.plist','_CodeSignature/CodeResources'}
        changes=[p for p in before if before[p]!=after[p]]
        require(set(changes)<=permitted_changes, 'Unexplained distribution bundle resource change')
        require(tree(archive)==earlier['archiveManifest'], 'Archive bytes changed after export')
        attempt.update({'inspection':inspection,'IPA':str(ipa),'IPASHA256':sha(ipa.read_bytes()),'archiveManifest':earlier['archiveManifest'],'archiveUnchanged':True,'archiveExportDecodedInfoPlistEqual':True,'archiveExportChangedFiles':changes,'archiveExportChangeClassification':'Code/provisioning/signature changes and semantically equal Info.plist serialization only; copied resources unchanged','status':'PASS'})
    elif args.operation=='upload':
        earlier=load_stage(args.platform,'local-export')
        require(tree(archive)==earlier['archiveManifest'], 'Archive changed before upload')
        require(sha(Path(earlier['IPA']).read_bytes())==earlier['IPASHA256'], 'Verified local IPA changed')
        require(tree(Path(earlier['inspection']['app']))==earlier['inspection']['bundleManifest'], 'Verified distribution inspection bundle changed')
        require(not Path(step['uploadOnlyAfterAllChecksAndRootAllocation']['argv'][step['uploadOnlyAfterAllChecksAndRootAllocation']['argv'].index('-exportPath')+1]).exists(), 'Upload output already exists')
        # Explicitly print only redacted actual candidate checks before upload.
        print(json.dumps({'event':'verified-upload-preflight','commit':COMMIT,'version':'1.0(1)','platform':args.platform,'families':step['expectedDeviceFamilies'],'distributionSignatureValid':True,'compiledEncryptionKeyPresent':True,'compiledEncryptionValue':False,'sourceAggregate':EXPECTED_AGGREGATE}),flush=True)
        log=run_xcode(step['uploadOnlyAfterAllChecksAndRootAllocation'],attempt)
        text=log.read_text(errors='replace')
        require('** EXPORT SUCCEEDED **' in text and 'Upload succeeded' in text, 'Successful delivery markers not both observed; do not infer upload')
        classification=classify_archive_after_upload(archive,earlier['archiveManifest'])
        require(sha(Path(earlier['IPA']).read_bytes())==earlier['IPASHA256'], 'Verified local IPA changed during upload')
        require(tree(Path(earlier['inspection']['app']))==earlier['inspection']['bundleManifest'], 'Verified distribution app changed during upload')
        attempt.update({'status':'PASS','archiveUnchanged':classification['archiveFullyByteIdentical'],'archivePayloadUnchanged':True,'archivePostUploadClassification':classification,'verifiedIPAAndDistributionAppUnchanged':True,'deliveryRecord':genuine_delivery_record(log),'uploadSucceededObserved':True,'processingMessageObserved':'Uploaded package is processing' in text,'submissionClaimed':False,'AppleFollowUp':'Root must freshly verify actual processed build, gallery/build selection and submission; delivery is not submission'})
    attempt['sourceAfter']=preflight()[3]

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--operation',choices=['preflight','archive','local-export','upload'],default='preflight')
    parser.add_argument('--platform',choices=['ipad','tvos'])
    parser.add_argument('--allocation-receipt')
    ARGS=parser.parse_args()
    if ARGS.operation!='preflight' and ARGS.platform is None: parser.error('Allocated operation requires exact platform')
    attempt={'startedAtUTC':now(),'releaseCommit':COMMIT,'approvedPlanSHA256':PLAN_SHA,'operation':ARGS.operation,'platform':ARGS.platform,'executorSHA256':sha(Path(__file__).read_bytes()),'noProductionEdits':True,'noPushDeviceBrowserOrLegalActions':True}
    receipt=LEAF/('executor-'+ARGS.operation+'-'+str(ARGS.platform or 'none')+'-'+uuid.uuid4().hex+'.json')
    exit_code=0
    try:
        main(ARGS,attempt)
    except Exception as error:
        exit_code=1;attempt.update({'status':'FAIL','errorType':type(error).__name__,'error':str(error),'failurePreserved':True})
        # Traceback contains code locations only; don't dump subprocess/profile output.
        attempt['traceback']=traceback.format_exc()
        try: attempt['sourceAfterFailure']=preflight()[3]
        except Exception as state_error: attempt['sourceAfterFailureError']=str(state_error)
    attempt['finishedAtUTC']=now();write_json(receipt,attempt)
    if attempt.get('status')=='PASS' and ARGS.operation!='preflight':
        stage_receipt=LEAF/(ARGS.platform+'-'+ARGS.operation+'-verified.json')
        write_json(stage_receipt,attempt)
    print(json.dumps({'operation':ARGS.operation,'platform':ARGS.platform,'status':attempt['status'],'receipt':str(receipt),'receiptSHA256':sha(receipt.read_bytes()),'error':attempt.get('error'),'commandExitCode':attempt.get('commandExitCode'),'actualXcodeExecuted':'commandStartedAtUTC' in attempt},indent=2),flush=True)
    sys.exit(exit_code)
