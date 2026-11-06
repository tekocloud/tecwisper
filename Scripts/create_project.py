#!/usr/bin/env python3
"""Regenerate the dependency-free Xcode project deterministically."""
import hashlib
from pathlib import Path
root = Path(__file__).resolve().parent.parent

def ident(name):
    return hashlib.sha1(name.encode()).hexdigest()[:24].upper()

objects = []
def obj(name, body):
    key = ident(name)
    objects.append(f'{key} = {{ {body} }};')
    return key

sources = sorted((root / 'TecWisper').rglob('*.swift'))
refs = []
builds = []
for path in sources:
    rel = path.relative_to(root).as_posix()
    ref = obj(rel, f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{rel}"; sourceTree = SOURCE_ROOT;')
    refs.append(ref)
    builds.append(obj('build:' + rel, f'isa = PBXBuildFile; fileRef = {ref};'))
for rel in ['TecWisper/Resources/Info.plist', 'TecWisper/Resources/TecWisper.entitlements', 'README.md']:
    refs.append(obj(rel, f'isa = PBXFileReference; path = "{rel}"; sourceTree = SOURCE_ROOT;'))
iconref = obj('icon', 'isa = PBXFileReference; lastKnownFileType = image.icns; path = TecWisper/Resources/TecWisperIcon.icns; sourceTree = SOURCE_ROOT;')
refs.append(iconref)
iconbuild = obj('iconbuild', f'isa = PBXBuildFile; fileRef = {iconref};')
brandbuilds = []
for path in sorted((root / 'TecWisper/Resources/Brand').glob('*.png')):
    rel = path.relative_to(root).as_posix()
    ref = obj(rel, f'isa = PBXFileReference; lastKnownFileType = image.png; path = "{rel}"; sourceTree = SOURCE_ROOT;')
    refs.append(ref)
    brandbuilds.append(obj('build:' + rel, f'isa = PBXBuildFile; fileRef = {ref};'))
product = obj('product' , 'isa = PBXFileReference; explicitFileType = wrapper.application; path = TecWisper.app; sourceTree = BUILT_PRODUCTS_DIR;')
products = obj('products', f'isa = PBXGroup; children = ({product},); name = Products; sourceTree = "<group>";')
main = obj('main', f'isa = PBXGroup; children = ({",".join(refs)}, {products},); sourceTree = "<group>";')
src = obj('sources', f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(builds)},); runOnlyForDeploymentPostprocessing = 0;')
frameworks = obj('frameworks', 'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
resource_ids = ','.join([iconbuild] + brandbuilds)
resources = obj('resources', f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({resource_ids},); runOnlyForDeploymentPostprocessing = 0;')
project_configs = []
target_configs = []
for config in ['Debug', 'Release']:
    project_configs.append(obj('project:' + config, f'isa = XCBuildConfiguration; name = {config}; buildSettings = {{ SDKROOT = macosx; MACOSX_DEPLOYMENT_TARGET = 14.0; CLANG_ENABLE_MODULES = YES; SWIFT_VERSION = 5.0; }};'))
    optimization = '-Onone' if config == 'Debug' else '-O'
    target_configs.append(obj('target:' + config, f'''isa = XCBuildConfiguration; name = {config}; buildSettings = {{
        PRODUCT_NAME = TecWisper; PRODUCT_BUNDLE_IDENTIFIER = de.teklacloud.TecWisper;
        INFOPLIST_FILE = TecWisper/Resources/Info.plist; GENERATE_INFOPLIST_FILE = NO;
        CODE_SIGN_ENTITLEMENTS = TecWisper/Resources/TecWisper.entitlements;
        CODE_SIGN_STYLE = Manual; CODE_SIGN_IDENTITY = "Apple Development"; DEVELOPMENT_TEAM = KQ84FGT625;
        ENABLE_HARDENED_RUNTIME = YES; ENABLE_APP_SANDBOX = NO;
        SWIFT_OPTIMIZATION_LEVEL = "{optimization}"; SWIFT_EMIT_LOC_STRINGS = NO;
        SWIFT_STRICT_CONCURRENCY = targeted; COMBINE_HIDPI_IMAGES = YES;
        LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/../Frameworks";
    }};'''))
pl = obj('projectconfigs', f'isa = XCConfigurationList; buildConfigurations = ({",".join(project_configs)},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
tl = obj('targetconfigs', f'isa = XCConfigurationList; buildConfigurations = ({",".join(target_configs)},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
target = obj('target', f'isa = PBXNativeTarget; buildConfigurationList = {tl}; buildPhases = ({src},{frameworks},{resources},); buildRules = (); dependencies = (); name = TecWisper; productName = TecWisper; productReference = {product}; productType = "com.apple.product-type.application";')
project = obj('project', f'isa = PBXProject; attributes = {{ LastSwiftUpdateCheck = 1600; LastUpgradeCheck = 1600; }}; buildConfigurationList = {pl}; compatibilityVersion = "Xcode 14.0"; developmentRegion = de; hasScannedForEncodings = 0; knownRegions = (de,en,Base,); mainGroup = {main}; productRefGroup = {products}; projectDirPath = ""; projectRoot = ""; targets = ({target},);')
(root / 'TecWisper.xcodeproj/project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n' + '\n'.join(objects) + f'\n}}; rootObject = {project}; }}\n')
(root / 'TecWisper.xcodeproj/xcshareddata/xcschemes/TecWisper.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="TecWisper.app" BlueprintName="TecWisper" ReferencedContainer="container:TecWisper.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="TecWisper.app" BlueprintName="TecWisper" ReferencedContainer="container:TecWisper.xcodeproj"/></BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"/>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
print('Xcode-Projekt aktualisiert.')
