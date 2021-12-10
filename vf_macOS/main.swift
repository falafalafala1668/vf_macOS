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
fileprivate var ipswPath = String()
fileprivate var vmFolder = String()
fileprivate var eth_if = ""
fileprivate var cpuCount: Int?
fileprivate var memory: UInt64?
fileprivate var diskSize: Int = 32

repeat {
    let ch = getopt(CommandLine.argc, CommandLine.unsafeArgv, "gn:f:b:p:m:d:")
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
    default:
        print("\(CommandLine.arguments[0]) -g(GUI) -f [VM Folder Path(Must)] -n(New Install) [ipsw Path] -p(cpu count) [count] -m(Memory Size) -d(Disk size) [32G]")
    }
} while (true)

let inst = VFMInstance(vmPath: vmFolder)

if isCreate {
    inst.startInstaller(with: URL(fileURLWithPath: ipswPath), diskSize: diskSize)
} else {
    inst.start(withGUI: showGUI)
}

RunLoop.main.run(until: Date.distantFuture)


