//
//  VFMInstance.swift
//  vf_macOS
//
//  Created by Mianmian on 2021/11/24.
//

import Virtualization

class VFMInstance: NSObject, VZVirtualMachineDelegate {
    
    var eth_if: String?
    var width: Int! = 2880
    var height: Int! = 1800
    
    private let vmURL: URL
    private var identifier: String = UUID().uuidString
    private var hardwareModelData: Data = Data()
    private var machineIdentifierData: Data = Data()
    private var storages: [VZStorageDeviceConfiguration] = []
    private var cpuCount: Int = 2
    private var memorySize: UInt64 = 4 * 1024 * 1024 * 1024
    private var ob: NSKeyValueObservation?
    private let internalDisk:URL
    
    init(vmPath: String) {
         vmURL = URL(fileURLWithPath: vmPath)
         
         var dic: [String:Any]?
         do {
             dic = try PropertyListSerialization.propertyList(from: Data(contentsOf: vmURL.appendingPathComponent("config.plist")), format: nil) as? [String:Any]
             identifier = dic?[UUID_D] as! String
             cpuCount = dic?[CPU_D] as! Int
             memorySize = dic?[MEMORY_D] as! UInt64
             hardwareModelData = dic?[hID_D] as! Data
             machineIdentifierData = dic?[mID_D] as! Data
         } catch {
            print("Missing config file, creating...")
         }
        internalDisk = self.vmURL.appendingPathComponent("disk.img")
         super.init()
    }
    
    func startInstaller(with ipswURL: URL, diskSize: Int) {
        VZMacOSRestoreImage.load(from: ipswURL) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let image):
                    self.startForInstallation(
                        image: image,
                        diskImageSize: diskSize)
                case .failure(let error):
                    NSLog("Error: \(error)")
                    exit(EXIT_FAILURE)
                }
            }
        }
    }
    
    func start(withGUI: Bool) {
        guard let hardwareModel = VZMacHardwareModel(dataRepresentation: hardwareModelData),
              let machineIdentifier = VZMacMachineIdentifier(dataRepresentation: machineIdentifierData) else {
                  exit(EXIT_FAILURE)
          }
        
        guard let configuration = getVMConfiguration(
            hardwareModel: hardwareModel,
            machineIdentifier: machineIdentifier,
            withSound: withGUI
        ) else {
            exit(EXIT_FAILURE)
        }
        
        do {
            try configuration.validate()
            
            let vm = VZVirtualMachine(configuration: configuration, queue: .main)
            vm.delegate = self
            
            let window = createNSWindow(with: vm)
            
            vm.start { result in
                switch result {
                case .success:
                    NSLog("Success")
                case .failure(let error):
                    NSLog("Error: \(error)")
                }
            }
            
            if withGUI {
                let ad = VFMAppDelegate()
                ad.window = window
                let app = NSApplication.shared
                app.delegate = ad;
                app.run()
            }
            
        } catch {
            NSLog("Error: \(error)")
            exit(EXIT_FAILURE)
        }
    }
    
    func attachDisk(diskURL: URL) {
        do {
            let attachment = try VZDiskImageStorageDeviceAttachment(
                url: diskURL,
                readOnly: false
            )
            let storage = VZVirtioBlockDeviceConfiguration(attachment: attachment)
            storages.append(storage)
        } catch {
            NSLog("Storage Error: \(error)")
        }
    }
    
    private func createNSWindow(with vm: VZVirtualMachine) -> NSWindow {
        let windowSize = NSSize(width: Int(Double(width)/2.25), height: Int(Double(height)/2.25))
//        let screenSize = NSScreen.main?.frame.size ?? .zero
        let rect = NSMakeRect(0, 0, windowSize.width, windowSize.height)
        let window = NSWindow(contentRect: rect, styleMask: [.titled,.closable,.miniaturizable], backing: .buffered, defer: false)
        window.title = "Virtual Machine"
        window.center()
        
        let vc = VFMVirtualMachineViewController()
        vc.vm = vm
        vc.view.frame = rect
        window.contentViewController = vc
        return window
    }
    
    private func startForInstallation(image: VZMacOSRestoreImage,
                                      diskImageSize: Int) {
        guard let supportedConfig = image.mostFeaturefulSupportedConfiguration else {
            NSLog("No supported config")
            exit(EXIT_FAILURE)
        }
        
        let machineIdentifier = VZMacMachineIdentifier()
        
        hardwareModelData = supportedConfig.hardwareModel.dataRepresentation
        machineIdentifierData = machineIdentifier.dataRepresentation
        
        do {
            let process = Process()
            process.launchPath = "/bin/dd"
            process.arguments = [
                "if=/dev/zero",
                "of=\(internalDisk.path)",
                "bs=1024m",
                "seek=\(diskImageSize)",
                "count=0"
            ]
            try process.run()
            process.waitUntilExit()
        } catch {
            NSLog("Failed to create disk image: \(error)")
            exit(EXIT_FAILURE)
        }
        
        guard let configuration = getVMConfiguration(
            hardwareModel: supportedConfig.hardwareModel,
            machineIdentifier: machineIdentifier,
            withSound: false
        ) else {
            NSLog("Can't get supported config")
            exit(EXIT_FAILURE)
        }
        NSLog("Installing...")
        do {
            try configuration.validate()
            
            let vm = VZVirtualMachine(configuration: configuration, queue: .main)
            vm.delegate = self
            
            let installer = VZMacOSInstaller(virtualMachine: vm, restoringFromImageAt: image.url)
            installer.install { [weak self] result in
                DispatchQueue.main.async { [self] in
                    switch result {
                    case .success:
                        NSLog("Success, add -g to finish setup")
                        self!.ob?.invalidate()
                        do {
                            try self!.savePropertyList()
                            exit(EXIT_SUCCESS)
                        } catch {
                            NSLog("Error: \(error)")
                            exit(EXIT_FAILURE)
                        }
                        
                    case .failure(let error):
                        NSLog("Error: \(error)")
                        exit(EXIT_FAILURE)
                    }
                }
            }
            
            ob = installer.progress.observe(\.fractionCompleted, changeHandler: { progress, _ in
                DispatchQueue.main.async {
                  NSLog("%i%%", Int(progress.completedUnitCount))
                }
              })
            
        } catch {
            NSLog("Error: \(error)")
            exit(EXIT_FAILURE)
        }
    }
    
    private func attachDisk() {
        do {
            let attachment = try VZDiskImageStorageDeviceAttachment(
                url: internalDisk,
                readOnly: false
            )
            let storage = VZVirtioBlockDeviceConfiguration(attachment: attachment)
            storages.insert(storage, at: 0)
        } catch {
            NSLog("Storage Error: \(error)")
        }
    }
    
    private func getVMConfiguration(hardwareModel: VZMacHardwareModel,
                                    machineIdentifier: VZMacMachineIdentifier,
                                    withSound: Bool) -> VZVirtualMachineConfiguration? {

        
        let bootloader = VZMacOSBootLoader()
        let entropy = VZVirtioEntropyDeviceConfiguration()
        let networkDevice = VZVirtioNetworkDeviceConfiguration()
        networkDevice.attachment = VZNATNetworkDeviceAttachment()
        
        let graphics = VZMacGraphicsDeviceConfiguration()
        graphics.displays = [
            VZMacGraphicsDisplayConfiguration(
                widthInPixels: width,
                heightInPixels: height,
                pixelsPerInch: 220
            )
        ]
        
        let keyboard = VZUSBKeyboardConfiguration()
        let pointingDevice = VZUSBScreenCoordinatePointingDeviceConfiguration()
        
        attachDisk()

        let configuration = VZVirtualMachineConfiguration()
        configuration.bootLoader = bootloader
        
        let platform = VZMacPlatformConfiguration()
        platform.hardwareModel = hardwareModel
        platform.machineIdentifier = machineIdentifier
        
        platform.auxiliaryStorage = try? VZMacAuxiliaryStorage(
            creatingStorageAt: vmURL.appendingPathComponent("boot.img"),
            hardwareModel: hardwareModel,
            options: [.allowOverwrite]
        )
        
        configuration.platform = platform
        
        configuration.cpuCount = cpuCount
        configuration.memorySize = memorySize
        configuration.entropyDevices = [entropy]
        configuration.networkDevices = [networkDevice]
        configuration.graphicsDevices = [graphics]
        configuration.keyboards = [keyboard]
        configuration.pointingDevices = [pointingDevice]
        configuration.storageDevices = storages
        if withSound {
            configuration.audioDevices = [addSoundDevice()]
        }
        return configuration
    }
    
    private func savePropertyList() throws {
        let dictionary = [UUID_D:identifier,CPU_D:cpuCount,MEMORY_D:memorySize,hID_D:hardwareModelData,mID_D:machineIdentifierData] as [String : Any]
        let plistData = try PropertyListSerialization.data(fromPropertyList: dictionary, format: .xml, options: 0)
        try plistData.write(to: vmURL.appendingPathComponent("config.plist"))
        
    }
    
    private func addSoundDevice() -> VZVirtioSoundDeviceConfiguration {
        let soundDevice = VZVirtioSoundDeviceConfiguration()
        let outputStream = VZVirtioSoundDeviceOutputStreamConfiguration()
        outputStream.sink = VZHostAudioOutputStreamSink()
        soundDevice.streams.append(outputStream)
        let inputStream = VZVirtioSoundDeviceInputStreamConfiguration()
        inputStream.source = VZHostAudioInputStreamSource()
        soundDevice.streams.append(inputStream)
        return soundDevice
    }
    
    func guestDidStop(_ virtualMachine: VZVirtualMachine) {
        exit(EXIT_SUCCESS)
    }
    
    func virtualMachine(_ virtualMachine: VZVirtualMachine, didStopWithError error: Error) {
        
    }
}
