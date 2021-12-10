//
//  VFMVirtualMachineViewController.swift
//  vf_macOS
//
//  Created by Mianmian on 2021/11/24.
//

import Cocoa
import Virtualization

class VFMVirtualMachineViewController: NSViewController {
    
    var vm: VZVirtualMachine?

    override func loadView() {
        let view = VZVirtualMachineView()
        view.capturesSystemKeys = true
        self.view = view
    }
    
    override func viewDidLoad() {
        (view as? VZVirtualMachineView)?.virtualMachine = vm
    }
    
}
