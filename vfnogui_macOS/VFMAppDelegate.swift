//
//  AppDelegate.swift
//  hjknjk
//
//  Created by Mianmian on 2021/11/25.
//

import Cocoa

class VFMAppDelegate: NSObject, NSApplicationDelegate {

    var window: NSWindow?
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        NSApp.setActivationPolicy(.regular)
        window?.makeKeyAndOrderFront(nil)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }


}

