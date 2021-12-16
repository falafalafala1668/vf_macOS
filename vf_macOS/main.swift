//
//  main.swift
//  vf_macOS
//
//  Created by Mianmian on 2021/11/24.
//

import Virtualization

let UUID_D = "UUID"
let CPU_D = "CPU"
let MEMORY_D = "Memory"
let SOUND_D = "Sound"
let hID_D = "hID"
let mID_D = "mID"

fileprivate var showGUI = false
fileprivate var isCreate = false
fileprivate var ipswPath: String?
fileprivate var vmFolder: String?
fileprivate var eth_if: String?
fileprivate var cpuCount: Int?
fileprivate var memory: UInt64?
fileprivate var diskSize: Int = 64
fileprivate var addDisk: URL?

func help() {
    print("\(CommandLine.arguments[0]) Syntax: -f <folderPath> <options>\n\t-f <folderPath>\t\t\tVM Folder Path(Must, Full Path)\n\t-g\t\t\t\t\t\tShow GUI\n\t-n <ipswPath>\t\t\tNew Install with ipsw Path\n\t-p <count>\t\t\t\tCPU Core Count(Default 2)\n\t-m <size>\t\t\t\tMemory Size(GB, min 4)\n\t-d <size>\t\t\t\tDisk size(GB, Default 64)\n\t-D <img path>\t\t\tAttach img path")
}

repeat {
    let ch = getopt(CommandLine.argc, CommandLine.unsafeArgv, "gn:f:b:p:m:d:D:h")
    if ch == -1 {
        break
    }
    switch UnicodeScalar(Int(ch)).flatMap(Character.init) {
    case "g":
        showGUI = true;
    case "n":
        isCreate = true;
        ipswPath = String(cString: optarg)
    case "f":
        vmFolder = String(cString: optarg)
    case "b":
        eth_if = String(cString: optarg)
    case "p":
        cpuCount = Int(atoi(optarg))
    case "m":
        memory = UInt64(atoi(optarg))
    case "d":
        diskSize = Int(atoi(optarg))
    case "D":
        addDisk = URL(fileURLWithPath: String(cString: optarg))
    default:
        help()
    }
} while (true)

let inst: VFMInstance

if vmFolder != nil {
    inst = VFMInstance(vmPath: vmFolder!)
} else {
    print("No VM Folder")
    help()
    exit(EXIT_FAILURE)
}

if cpuCount != nil {
    inst.cpuCount = cpuCount!
}

if memory != nil {
    inst.memorySize = memory!
}

if addDisk != nil {
    inst.attachDisk(diskURL: addDisk!)
}

if isCreate {
    if ipswPath == nil {
        print("No IPSW path")
        help()
        exit(EXIT_FAILURE)
    }
    inst.startInstaller(with: URL(fileURLWithPath: ipswPath!), diskSize: diskSize)
} else {
    inst.start(withGUI: showGUI)
}

RunLoop.main.run(until: Date.distantFuture)


