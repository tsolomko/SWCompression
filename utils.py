#!/usr/bin/env python3

import argparse
import subprocess
import sys

def _sprun(cmd, *args, **kwargs):
    print("+ " + " ".join(cmd))
    subprocess.run(cmd, check=True, *args, **kwargs)

def _ci_before_deploy():
    print("=> Removing bcsymbolmap files for dependencies.")
    platforms = ["Mac", "watchOS", "tvOS", "iOS"]
    for platform in platforms:
        _sprun(["rm", "-f", "Carthage/Build/{0}/*.bcsymbolmap".format(platform)])
    print("=> Removing checkouts for dependencies.")
    _sprun(["rm", "-rf", "Carthage/Checkouts"])
    print("=> Preparing deployment files.")
    _sprun(["carthage", "build", "--no-skip-current"])
    _sprun(["carthage", "archive", "SWCompression"])
    docs_json_file = open("docs.json", "w")
    _sprun(["sourcekitten", "doc", "--spm-module", "SWCompression"], stdout=docs_json_file)
    docs_json_file.close()
    _sprun(["jazzy"])

def _ci_install_macos():
    _sprun(["brew", "install", "git-lfs"])
    _sprun(["git", "lfs", "install"])
    _sprun(["gem", "install", "-N", "xcpretty-travis-formatter"])

def _ci_script_linux():
    _sprun(["swift", "build"])
    _sprun(["swift", "build", "-c", "release"])

def _ci_script_macos():
    xcodebuild_command_parts = ["xcodebuild", "-project", "SWCompression.xcodeproj", "-scheme", "SWCompression"]
    destinations_actions = [(["-destination 'platform=OS X'"], ["clean", "test"]), 
                    (["-destination 'platform=iOS Simulator,name=iPhone 8'"], ["clean", "test"]), 
                    (["-destination 'platform=watchOS Simulator,name=Apple Watch - 38mm'"], ["clean", "build"]), 
                    (["-destination 'platform=tvOS Simulator,name=Apple TV'"], ["clean", "test"])]
    
    for destination, action in destinations_actions:
        xcodebuild_command = xcodebuild_command_parts + destination + action
        print("+ {0}".format(" ".join(xcodebuild_command)))
        xcodebuild_process = subprocess.Popen(xcodebuild_command, stdout=subprocess.PIPE)
        xcpretty_command = ["xcpretty", "-f", "`xcpretty-travis-formatter`"]
        subprocess.run(xcpretty_command, stdin=xcodebuild_process.stdout, shell=True, check=True)

def action_ci(args):
    if args.cmd == "before-deploy":
        _ci_before_deploy()
    elif args.cmd == "install-macos":
        _ci_install_macos()
    elif args.cmd == "script-linux":
        _ci_script_linux()
    elif args.cmd == "script-macos":
        _ci_script_macos()
    else:
        raise Exception("Unknown CI command")

parser = argparse.ArgumentParser(description="A tool with useful commands for developing SWCompression")
subparsers = parser.add_subparsers(title="commands", help="a command to perform", metavar="CMD")

# Parser for 'ci' command.
parser_ci = subparsers.add_parser("ci", help="a set of commands used by CI", description="a set of commands used by CI")
parser_ci.add_argument("cmd", choices=["before-deploy", "install-macos", "script-linux", "script-macos"],
                        help="a command to perform on CI", metavar="CI_CMD")
parser_ci.set_defaults(func=action_ci)

args = parser.parse_args()
args.func(args)
