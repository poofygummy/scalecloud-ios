#!/usr/bin/env python3
"""
Add three missing Swift files to Xcode project:
- ScaleCloudWatchedFoldersModel.swift (Account Settings)
- ScaleCloudWatchedFoldersView.swift (Account Settings)
- ScaleCloudDownloadsHelper.swift (Utility)
"""

import sys

# UUIDs generated
WATCHED_MODEL_BUILD = "052BC52BFCB0474FA470514D"
WATCHED_VIEW_BUILD = "0E6B52E66369416F8479C61A"
DOWNLOADS_BUILD = "05388DCFF7354DEAB98B07A7"
WATCHED_MODEL_REF = "8DCC8E314AD94E6D9EDF6472"
WATCHED_VIEW_REF = "B2252E40FB05477C97F6F21E"
DOWNLOADS_REF = "3729FE4C077B475889840738"

def add_files_to_project(filepath):
    with open(filepath, 'r') as f:
        lines = f.readlines()
    
    # Find insertion points
    build_file_insert_line = None
    file_ref_insert_line = None
    account_settings_insert_line = None
    utility_insert_line = None
    sources_insert_line = None
    
    for i, line in enumerate(lines):
        # Find PBXBuildFile insertion point (after NCAccountSettingsView.swift line)
        # Must have = {isa = PBXBuildFile to distinguish from Sources section
        if 'F7FDFF6E2E437E55000D7688 /* NCAccountSettingsView.swift in Sources */' in line and '= {isa = PBXBuildFile' in line:
            build_file_insert_line = i + 1
        
        # Find PBXFileReference insertion point (after NCAccountSettingsView.swift line)
        if 'F7FDFF572E437E55000D7688 /* NCAccountSettingsView.swift */ = {isa = PBXFileReference' in line:
            file_ref_insert_line = i + 1
        
        # Find Account Settings group insertion point (after NCAccountSettingsView.swift line in children)
        if i > 0 and 'F7FDFF572E437E55000D7688 /* NCAccountSettingsView.swift */,' in line and 'children' in lines[i-2]:
            account_settings_insert_line = i + 1
        
        # Find Utility group insertion point (after NCUtilityFileSystem.swift)
        if 'F74AF3A3247FB6AE00AC767B /* NCUtilityFileSystem.swift */,' in line:
            utility_insert_line = i + 1
        
        # Find Sources build phase insertion point (after NCAccountSettingsView.swift in Sources)
        # Must have comma and NOT have = {isa to distinguish from BuildFile section
        if 'F7FDFF6E2E437E55000D7688 /* NCAccountSettingsView.swift in Sources */,' in line and '= {isa' not in line:
            sources_insert_line = i + 1
    
    if not all([build_file_insert_line, file_ref_insert_line, account_settings_insert_line, 
                utility_insert_line, sources_insert_line]):
        print(f"ERROR: Could not find all insertion points:")
        print(f"  build_file_insert_line: {build_file_insert_line}")
        print(f"  file_ref_insert_line: {file_ref_insert_line}")
        print(f"  account_settings_insert_line: {account_settings_insert_line}")
        print(f"  utility_insert_line: {utility_insert_line}")
        print(f"  sources_insert_line: {sources_insert_line}")
        return False
    
    print(f"Found insertion points:")
    print(f"  PBXBuildFile: line {build_file_insert_line}")
    print(f"  PBXFileReference: line {file_ref_insert_line}")
    print(f"  Account Settings group: line {account_settings_insert_line}")
    print(f"  Utility group: line {utility_insert_line}")
    print(f"  Sources build phase: line {sources_insert_line}")
    
    # Insert in reverse order to preserve line numbers
    insertions = []
    
    # 1. Add to PBXBuildFile section (line ~944-945)
    insertions.append((build_file_insert_line, [
        f"\t\t{WATCHED_MODEL_BUILD} /* ScaleCloudWatchedFoldersModel.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {WATCHED_MODEL_REF} /* ScaleCloudWatchedFoldersModel.swift */; }};\n",
        f"\t\t{WATCHED_VIEW_BUILD} /* ScaleCloudWatchedFoldersView.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {WATCHED_VIEW_REF} /* ScaleCloudWatchedFoldersView.swift */; }};\n",
        f"\t\t{DOWNLOADS_BUILD} /* ScaleCloudDownloadsHelper.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {DOWNLOADS_REF} /* ScaleCloudDownloadsHelper.swift */; }};\n",
    ]))
    
    # 2. Add to PBXFileReference section (line ~1879-1880)
    insertions.append((file_ref_insert_line, [
        f"\t\t{WATCHED_MODEL_REF} /* ScaleCloudWatchedFoldersModel.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ScaleCloudWatchedFoldersModel.swift; sourceTree = \"<group>\"; }};\n",
        f"\t\t{WATCHED_VIEW_REF} /* ScaleCloudWatchedFoldersView.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ScaleCloudWatchedFoldersView.swift; sourceTree = \"<group>\"; }};\n",
        f"\t\t{DOWNLOADS_REF} /* ScaleCloudDownloadsHelper.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ScaleCloudDownloadsHelper.swift; sourceTree = \"<group>\"; }};\n",
    ]))
    
    # 3. Add to Account Settings group (line ~3444-3445)
    insertions.append((account_settings_insert_line, [
        f"\t\t\t\t{WATCHED_MODEL_REF} /* ScaleCloudWatchedFoldersModel.swift */,\n",
        f"\t\t\t\t{WATCHED_VIEW_REF} /* ScaleCloudWatchedFoldersView.swift */,\n",
    ]))
    
    # 4. Add to Utility group (after NCUtilityFileSystem.swift)
    insertions.append((utility_insert_line, [
        f"\t\t\t\t{DOWNLOADS_REF} /* ScaleCloudDownloadsHelper.swift */,\n",
    ]))
    
    # 5. Add to Sources build phase (line ~4864-4865)
    insertions.append((sources_insert_line, [
        f"\t\t\t\t{WATCHED_MODEL_BUILD} /* ScaleCloudWatchedFoldersModel.swift in Sources */,\n",
        f"\t\t\t\t{WATCHED_VIEW_BUILD} /* ScaleCloudWatchedFoldersView.swift in Sources */,\n",
        f"\t\t\t\t{DOWNLOADS_BUILD} /* ScaleCloudDownloadsHelper.swift in Sources */,\n",
    ]))
    
    # Sort by line number in reverse order
    insertions.sort(key=lambda x: x[0], reverse=True)
    
    # Apply insertions
    for line_num, new_lines in insertions:
        print(f"Inserting {len(new_lines)} lines at line {line_num}")
        for new_line in reversed(new_lines):
            lines.insert(line_num, new_line)
    
    # Write back
    with open(filepath, 'w') as f:
        f.writelines(lines)
    
    print(f"\nSuccessfully added 3 files to project!")
    return True

if __name__ == '__main__':
    filepath = 'ScaleCloudApp/ScaleCloudApp.xcodeproj/project.pbxproj'
    success = add_files_to_project(filepath)
    sys.exit(0 if success else 1)
