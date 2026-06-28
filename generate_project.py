#!/usr/bin/env python3
"""Generate Xcode project.pbxproj for RosterChecker"""

import uuid, os

def uid():
    return uuid.uuid4().hex[:24].upper()

PROJ_DIR = os.path.dirname(os.path.abspath(__file__))
SRC_DIR = os.path.join(PROJ_DIR, "RosterChecker")

# Generate UUIDs
files = {
    "App": ("RosterCheckerApp.swift", "sourcecode.swift"),
    "ContentView": ("ContentView.swift", "sourcecode.swift"),
    "ViewModel": ("RosterViewModel.swift", "sourcecode.swift"),
    "Python": ("verify_roster.py", "text.script.python"),
    "Assets": ("Assets.xcassets", "folder.assetcatalog"),
    "Info": ("Info.plist", "text.plist.xml"),
    "Products": ("Products", "folder"),
}

for k in files:
    files[k] = (files[k][0], files[k][1], uid())

# Product
app_ref_uid = uid()

# Build files
bf_sources = {}
for k in ["App", "ContentView", "ViewModel"]:
    bf_sources[k] = uid()

bf_resources = {}
for k in ["Python", "Assets"]:
    bf_resources[k] = uid()

# Build phases
sources_phase_uid = uid()
resources_phase_uid = uid()

# Target
target_uid = uid()
target_product_uid = uid()

# Project
project_uid = uid()
main_group_uid = uid()
src_group_uid = uid()
products_group_uid = uid()

# Config
debug_config_uid = uid()
release_config_uid = uid()
config_list_project_uid = uid()
config_list_target_uid = uid()

# Native target build phases
build_phases_target = [sources_phase_uid, resources_phase_uid]

pbxproj = f"""// !$*UTF8*$!
{{
    archiveVersion = 1;
    classes = {{}};
    objectVersion = 56;
    objects = {{

/* Begin PBXBuildFile section */
"""
for k, buid in bf_sources.items():
    pbxproj += f"\t\t{buid} /* {files[k][0]} in Sources */ = {{isa = PBXBuildFile; fileRef = {files[k][2]} /* {files[k][0]} */; }};\n"

for k, buid in bf_resources.items():
    pbxproj += f"\t\t{buid} /* {files[k][0]} in Resources */ = {{isa = PBXBuildFile; fileRef = {files[k][2]} /* {files[k][0]} */; }};\n"

pbxproj += """/* End PBXBuildFile section */

/* Begin PBXFileReference section */
"""
for k, (name, ftype, fuid) in files.items():
    if k in ["Products"]:
        pbxproj += f"\t\t{fuid} /* {name} */ = {{isa = PBXGroup; children = ({app_ref_uid}); name = Products; sourceTree = \"<group>\"; }};\n"
    elif k == "Assets":
        pbxproj += f"\t\t{fuid} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = {ftype}; path = {name}; sourceTree = \"<group>\"; }};\n"
    else:
        pbxproj += f"\t\t{fuid} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = {ftype}; path = {name}; sourceTree = \"<group>\"; }};\n"

pbxproj += f"""\t\t{app_ref_uid} /* RosterChecker.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = RosterChecker.app; sourceTree = BUILT_PRODUCTS_DIR; }};
/* End PBXFileReference section */

/* Begin PBXGroup section */
\t\t{main_group_uid} /* = */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{src_group_uid} /* RosterChecker */,
\t\t\t\t{products_group_uid} /* Products */,
\t\t\t);
\t\t\tsourceTree = \"<group>\";
\t\t}};
\t\t{src_group_uid} /* RosterChecker */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{files['App'][2]} /* RosterCheckerApp.swift */,
\t\t\t\t{files['ContentView'][2]} /* ContentView.swift */,
\t\t\t\t{files['ViewModel'][2]} /* RosterViewModel.swift */,
\t\t\t\t{files['Python'][2]} /* verify_roster.py */,
\t\t\t\t{files['Assets'][2]} /* Assets.xcassets */,
\t\t\t\t{files['Info'][2]} /* Info.plist */,
\t\t\t);
\t\t\tpath = RosterChecker;
\t\t\tsourceTree = \"<group>\";
\t\t}};
\t\t{products_group_uid} /* Products */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{app_ref_uid} /* RosterChecker.app */,
\t\t\t);
\t\t\tname = Products;
\t\t\tsourceTree = \"<group>\";
\t\t}};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
\t\t{target_uid} /* RosterChecker */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {config_list_target_uid} /* Build configuration list for PBXNativeTarget "RosterChecker" */;
\t\t\tbuildPhases = (
\t\t\t\t{sources_phase_uid} /* Sources */,
\t\t\t\t{resources_phase_uid} /* Resources */,
\t\t\t);
\t\t\tbuildRules = ();
\t\t\tdependencies = ();
\t\t\tname = RosterChecker;
\t\t\tproductName = RosterChecker;
\t\t\tproductReference = {app_ref_uid} /* RosterChecker.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
\t\t{project_uid} /* Project object */ = {{
\t\t\tisa = PBXProject;
\t\t\tattributes = {{
\t\t\t\tBuildIndependentTargetsInParallel = 1;
\t\t\t\tLastSwiftUpdateCheck = 1500;
\t\t\t\tLastUpgradeCheck = 1500;
\t\t\t}};
\t\t\tbuildConfigurationList = {config_list_project_uid} /* Build configuration list for PBXProject "RosterChecker" */;
\t\t\tcompatibilityVersion = "Xcode 14.0";
\t\t\tdevelopmentRegion = en;
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (en, Base, "zh-Hans");
\t\t\tmainGroup = {main_group_uid};
\t\t\tproductRefGroup = {products_group_uid} /* Products */;
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = (
\t\t\t\t{target_uid} /* RosterChecker */,
\t\t\t);
\t\t}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
\t\t{resources_phase_uid} /* Resources */ = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
"""
for k, buid in bf_resources.items():
    pbxproj += f"\t\t\t\t{buid} /* {files[k][0]} in Resources */,\n"

pbxproj += f"""\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
\t\t{sources_phase_uid} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
"""
for k, buid in bf_sources.items():
    pbxproj += f"\t\t\t\t{buid} /* {files[k][0]} in Sources */,\n"

pbxproj += f"""\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
\t\t{debug_config_uid} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
\t\t\t\tCLANG_ANALYZER_NONNULL = YES;
\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tENABLE_TESTABILITY = YES;
\t\t\t\tGCC_DYNAMIC_NO_PIC = NO;
\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;
\t\t\t\tGCC_PREPROCESSOR_DEFINITIONS = ("DEBUG=1");
\t\t\t\tINFOPLIST_FILE = RosterChecker/Info.plist;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = ("$(inherited)", "@executable_path/../Frameworks");
\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 14.0;
\t\t\t\tMTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.rosterchecker.app;
\t\t\t\tPRODUCT_NAME = "花名册核对";
\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{release_config_uid} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
\t\t\t\tCLANG_ANALYZER_NONNULL = YES;
\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
\t\t\t\tENABLE_NS_ASSERTIONS = NO;
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tGCC_OPTIMIZATION_LEVEL = s;
\t\t\t\tINFOPLIST_FILE = RosterChecker/Info.plist;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = ("$(inherited)", "@executable_path/../Frameworks");
\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 14.0;
\t\t\t\tMTL_ENABLE_DEBUG_INFO = NO;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.rosterchecker.app;
\t\t\t\tPRODUCT_NAME = "花名册核对";
\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-O";
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t}};
\t\t\tname = Release;
\t\t}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
\t\t{config_list_project_uid} /* Build configuration list for PBXProject "RosterChecker" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{debug_config_uid} /* Debug */,
\t\t\t\t{release_config_uid} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
\t\t{config_list_target_uid} /* Build configuration list for PBXNativeTarget "RosterChecker" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{debug_config_uid} /* Debug */,
\t\t\t\t{release_config_uid} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
/* End XCConfigurationList section */
    }};
    rootObject = {project_uid} /* Project object */;
}}
"""

# Write project.pbxproj
proj_dir = os.path.join(PROJ_DIR, "RosterChecker.xcodeproj")
os.makedirs(proj_dir, exist_ok=True)

with open(os.path.join(proj_dir, "project.pbxproj"), "w") as f:
    f.write(pbxproj)

print("project.pbxproj generated successfully")
