#!/usr/bin/env python3

import argparse
import subprocess
import sys

def _sprun(cmd, *args, **kwargs):
    print("+ " + " ".join(cmd))
    subprocess.run(cmd, check=True, *args, **kwargs)

def _ci_before_deploy():
    docs_json_file = open("docs.json", "w")
    _sprun(["sourcekitten", "doc", "--spm", "--module-name", "SWCompression"], stdout=docs_json_file)
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
        print("+ {0} | xcpretty -f `xcpretty-travis-formatter`".format(" ".join(xcodebuild_command)))
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

def action_cw(args):
    _sprun(["rm", "-rf", "build/"])
    _sprun(["rm", "-rf", "Carthage/"])
    _sprun(["rm", "-rf", "docs/"])
    _sprun(["rm", "-rf", "Pods/"])
    _sprun(["rm", "-rf", ".build/"])
    _sprun(["rm", "-f", "Cartfile.resolved"])
    _sprun(["rm", "-f", "docs.json"])
    _sprun(["rm", "-f", "Package.resolved"])
    _sprun(["rm", "-f", "SWCompression.framework.zip"])

def _pw_macos():
    print("=> Downloading dependency (BitByteData) using Carthage")
    _sprun(["carthage", "bootstrap", "--no-use-binaries"])

def action_pw(args):
    if args.os == "macos":
        _pw_macos()
    elif args.os == "other":
        pass
    else:
        raise Exception("Unknown OS")
    if not args.no_test_files:
        print("=> Downloading files used for testing")
        _sprun(["git", "submodule", "update", "--init", "--recursive"])
        _sprun(["cp", "Tests/Test Files/gitattributes-copy", "Tests/Test Files/.gitattributes"])
        _sprun(["git", "lfs", "pull"], cwd="Tests/Test Files/")
        _sprun(["git", "lfs", "checkout"], cwd="Tests/Test Files/")

parser = argparse.ArgumentParser(description="A tool with useful commands for developing SWCompression")
subparsers = parser.add_subparsers(title="commands", help="a command to perform", metavar="CMD")

# Parser for 'ci' command.
parser_ci = subparsers.add_parser("ci", help="a subset of commands used by CI",
                                    description="a subset of commands used by CI")
parser_ci.add_argument("cmd", choices=["before-deploy", "install-macos", "script-linux", "script-macos"],
                        help="a command to perform on CI", metavar="CI_CMD")
parser_ci.set_defaults(func=action_ci)

# Parser for 'cleanup-workspace' command.
parser_cw = subparsers.add_parser("cleanup-workspace", help="cleanup workspace",
                            description="cleans workspace from files produced by various build systems")
parser_cw.set_defaults(func=action_cw)

# Parser for 'prepare-workspace' command.
parser_pw = subparsers.add_parser("prepare-workspace", help="prepare workspace",
                            description="prepares workspace for developing SWCompression")
parser_pw.add_argument("os", choices=["macos", "other"], help="development operating system", metavar="OS")
parser_pw.add_argument("--no-test-files", "-T", action="store_true", dest="no_test_files",
                        help="don't download example files used for testing")
parser_pw.set_defaults(func=action_pw)

args = parser.parse_args()
args.func(args)
