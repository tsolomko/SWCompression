#!/usr/bin/env python3

import argparse
import os
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
    script = """if brew ls --versions "git-lfs" >/dev/null; then
                    HOMEBREW_NO_AUTO_UPDATE=1 brew upgrade "git-lfs"
                else
                    HOMEBREW_NO_AUTO_UPDATE=1 brew install "git-lfs"
                fi"""
    _sprun([script], shell=True)
    _sprun(["git", "lfs", "install"])
    _sprun(["gem", "install", "-N", "xcpretty-travis-formatter"])

def _ci_install_linux():
    _sprun(["eval \"$(curl -sL https://swiftenv.fuller.li/install.sh)\""], shell=True)

def _ci_script_macos(new_watchos_simulator):
    _sprun(["swift", "--version"])
    xcodebuild_command_parts = ["xcodebuild", "-quiet", "-project", "SWCompression.xcodeproj", "-scheme", "SWCompression"]
    destinations_actions = [(["-destination 'platform=OS X'"], ["clean", "test"]), 
                    (["-destination 'platform=iOS Simulator,name=iPhone 8'"], ["clean", "test"]), 
                    (["-destination 'platform=tvOS Simulator,name=Apple TV'"], ["clean", "test"])]

    if new_watchos_simulator:
        destinations_actions.append((["-destination 'platform=watchOS Simulator,name=Apple Watch Series 6 - 44mm'"], ["clean", "build"]))
    else:
        destinations_actions.append((["-destination 'platform=watchOS Simulator,name=Apple Watch - 38mm'"], ["clean", "build"]))

    for destination, action in destinations_actions:
        xcodebuild_command = xcodebuild_command_parts + destination + action
        print("+ {0} | xcpretty -f `xcpretty-travis-formatter`".format(" ".join(xcodebuild_command)))
        xcodebuild_process = subprocess.Popen(xcodebuild_command, stdout=subprocess.PIPE)
        xcpretty_command = ["xcpretty", "-f", "`xcpretty-travis-formatter`"]
        subprocess.run(xcpretty_command, stdin=xcodebuild_process.stdout, shell=True, check=True)

def _ci_script_linux():
    env = os.environ.copy()
    env["SWIFTENV_ROOT"] = env["HOME"] +"/.swiftenv"
    env["PATH"] = env["SWIFTENV_ROOT"] + "/bin:" + env["SWIFTENV_ROOT"] + "/shims:"+ env["PATH"]
    _sprun(["swift", "--version"], env=env)
    _sprun(["swift", "build"], env=env)
    _sprun(["swift", "build", "-c", "release"], env=env)

def action_ci(args):
    if args.cmd == "before-deploy":
        _ci_before_deploy()
    elif args.cmd == "install-macos":
        _ci_install_macos()
    elif args.cmd == "install-linux":
        _ci_install_linux()
    elif args.cmd == "script-macos":
        _ci_script_macos(args.new_watchos_simulator)
    elif args.cmd == "script-linux":
        _ci_script_linux()
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

def _pw_macos(debug, xcf):
    print("=> Downloading dependency (BitByteData) using Carthage")
    script = ["carthage", "bootstrap", "--no-use-binaries"]
    if debug:
        script += ["--configuration", "Debug"]
    if xcf:
        script += ["--use-xcframeworks"]
    _sprun(script)
        
def action_pw(args):
    if args.os == "macos":
        _pw_macos(args.debug, args.xcf)
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
parser_ci.add_argument("cmd", choices=["before-deploy", "install-macos", "install-linux", "script-macos", "script-linux"],
                        help="a command to perform on CI", metavar="CI_CMD")
parser_ci.add_argument("--new-watchos-simulator", action="store_true", dest="new_watchos_simulator",
                        help="use the newest watchos simulator which is necessary for xcode 12+ \
                        (used only by 'script-macos' subcommand)")
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
parser_pw.add_argument("--debug", "-d", action="store_true", dest="debug",
                        help="build BitByteData in Debug configuration")
parser_pw.add_argument("--xcf", action="store_true", dest="xcf",
                        help="build BitByteData as a XCFramework")
parser_pw.set_defaults(func=action_pw)

args = parser.parse_args()
args.func(args)
