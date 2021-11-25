//
//  main.swift
//  vf_macOS
//
//  Created by Mianmian on 2021/11/24.
//

import Virtualization

var showGUI = false
var isCreate = false
var ipswPath = String()
var vmFolder = String()
var eth_if = ""
var cpuCount = 0
var memory = UInt64()
//
//print(CommandLine.arguments)

repeat {
    let ch = getopt(CommandLine.argc, CommandLine.unsafeArgv, "gn:f:b:p:m:")
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
    default:
        print("weg")
    }
} while (true)

let windowSize = NSSize(width: 1280, height: 800)
let screenSize = NSScreen.main?.frame.size ?? .zero
let rect = NSMakeRect(0, 0, windowSize.width, windowSize.height)
let window = NSWindow(contentRect: rect, styleMask: [.titled], backing: .buffered, defer: false)
let inst = VFMInstance(vmPath: vmFolder)

if isCreate {
    inst.startInstaller(with: URL(fileURLWithPath: ipswPath), completion: { result in
        
    })
} else {
    inst.start(completion: { vm in
        let vc = VFMVirtualMachineViewController()
        vc.vm = vm
        vc.view.frame = rect
        window.contentViewController = vc
    })
}

if showGUI {
    let ad = VFMAppDelegate()
    ad.window = window
    let app = NSApplication.shared
    app.delegate = ad;
    app.run()
}

RunLoop.main.run(until: Date.distantFuture)


