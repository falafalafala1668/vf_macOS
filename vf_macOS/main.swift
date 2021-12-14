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
fileprivate var diskSize: Int = 32
fileprivate var addDisk: URL?

func help() {
    print("\(CommandLine.arguments[0]) -g(GUI) -f [VM Folder Path(Must)] -n(New Install) [ipsw Path] -p(cpu count) [count] -m(Memory Size) -d(Disk size) [32G] -a(Attach img)")
}

repeat {
    let ch = getopt(CommandLine.argc, CommandLine.unsafeArgv, "gn:f:b:p:m:d:a:")
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
    case "a":
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

if addDisk != nil {
    inst.attachDisk(diskURL: addDisk!)
}

if isCreate {
    guard let ipsw = ipswPath else {
        print("No IPSW path")
        help()
        exit(EXIT_FAILURE)
    }
    inst.startInstaller(with: URL(fileURLWithPath: ipsw), diskSize: diskSize)
} else {
    inst.start(withGUI: showGUI)
}

RunLoop.main.run(until: Date.distantFuture)


