//
//  VFMInstance.swift
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

class VFMInstance: NSObject, VZVirtualMachineDelegate {
    
     private let vmURL: URL
     
     var eth_if: String?
     
     var cpuCount: Int = 2
     
     var memorySize: UInt64 = 4 * 1024 * 1024 * 1024
     
     private var hardwareModelData: Data = Data()
     
     private var machineIdentifierData: Data = Data()
     
     var identifier: String = UUID().uuidString
    
     var vm: VZVirtualMachine?
     
     init(vmPath: String) {
         vmURL = URL(fileURLWithPath: vmPath)
         
         var dic: [String:Any] = Dictionary()
         do {
             dic = try PropertyListSerialization.propertyList(from: Data(contentsOf: vmURL.appendingPathComponent("config.plist")), format: nil) as! [String:Any]
             identifier = dic[UUID_D] as! String
             cpuCount = dic[CPU_D] as! Int
//             memorySize = dic[MEMORY_D] as! UInt64
             hardwareModelData = dic[hID_D] as! Data
             machineIdentifierData = dic[mID_D] as! Data
         } catch {
            print(error)
         }
         
         super.init()
     }
    
    func startInstaller(with ipswURL: URL,
                        completion: @escaping (Bool) -> Void) {
//        isInstalling = true
        VZMacOSRestoreImage.load(from: ipswURL) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let image):
                    self.startForInstallation(
                        image: image,
                    diskImageSize: 40)
                case .failure(let error):
//                    self.isInstalling = false
                    completion(false)
                    NSLog("Error: \(error)")
                }
            }
        }
    }
    
    private func startForInstallation(image: VZMacOSRestoreImage,
                                      diskImageSize: Int) {
        guard let supportedConfig = image.mostFeaturefulSupportedConfiguration else {
            NSLog("No supported config")
//            isInstalling = false
//            completion(false)
            return
        }
        
        let machineIdentifier = VZMacMachineIdentifier()
        
        hardwareModelData = supportedConfig.hardwareModel.dataRepresentation
        machineIdentifierData = machineIdentifier.dataRepresentation
        
        let diskURL = vmURL.appendingPathComponent("disk.img")
        
        do {
            let process = Process()
            process.launchPath = "/bin/dd"
            process.arguments = [
                "if=/dev/zero",
                "of=\(diskURL.path)",
                "bs=1024m",
                "seek=\(diskImageSize)",
                "count=0"
            ]
            try process.run()
            process.waitUntilExit()
        } catch {
            NSLog("Failed to create disk image")
        }
        
        
        guard let configuration = getVMConfiguration(
            hardwareModel: supportedConfig.hardwareModel,
            machineIdentifier: machineIdentifier,
            diskURL: diskURL,
            auxiliaryStorageURL: vmURL.appendingPathComponent("aux.img")
        ) else {
//            isInstalling = false
            return
        }
        
        do {
            try configuration.validate()
            
            let vm = VZVirtualMachine(configuration: configuration, queue: .main)
            vm.delegate = self
            
            let installer = VZMacOSInstaller(virtualMachine: vm, restoringFromImageAt: image.url)
            installer.install { [weak self] result in
                DispatchQueue.main.async { [self] in
                    switch result {
                    case .success:
                        NSLog("Success")
                        do {
                            try self!.savePropertyList()
                            exit(0)
                        } catch {
                            NSLog("Error: \(error)")
                        }
//                        self?.document?.content.installed = true
                    case .failure(let error):
                        NSLog("Error: \(error)")
                    }
//                    self?.isInstalling = false
//                    completion(true)
                }
            }
            
//            self.virtualMachine = vm
//            self.installer = installer
            
//            document?.vmInstallationState.progress = installer.progress
        } catch {
            NSLog("Error: \(error)")
//            isInstalling = false
//            completion(false)
        }
    }
    func start(completion: @escaping (VZVirtualMachine) -> Void) {
       
        guard let hardwareModel = VZMacHardwareModel(dataRepresentation: hardwareModelData),
              let machineIdentifier = VZMacMachineIdentifier(dataRepresentation: machineIdentifierData) else {
              return
          }
        
        guard let configuration = getVMConfiguration(
            hardwareModel: hardwareModel,
            machineIdentifier: machineIdentifier,
            diskURL: vmURL.appendingPathComponent("disk.img"),
            auxiliaryStorageURL: vmURL.appendingPathComponent("aux.img")
        ) else {
            return
        }
        
        do {
            try configuration.validate()
            
            let vm = VZVirtualMachine(configuration: configuration, queue: .main)
            vm.delegate = self
            
            vm.start { result in
                switch result {
                case .success:
                    NSLog("Success")
                    completion(vm)
                case .failure(let error):
                    NSLog("Error: \(error)")
                }
            }
        } catch {
            NSLog("Error: \(error)")
        }
    }
    
    func savePropertyList() throws {
        let dictionary = [UUID_D:identifier,CPU_D:cpuCount,MEMORY_D:memory,hID_D:hardwareModelData,mID_D:machineIdentifierData] as [String : Any]
        let plistData = try PropertyListSerialization.data(fromPropertyList: dictionary, format: .xml, options: 0)
        try plistData.write(to: vmURL.appendingPathComponent("config.plist"))
        
    }
    
    private func getVMConfiguration(hardwareModel: VZMacHardwareModel,
                                    machineIdentifier: VZMacMachineIdentifier,
                                    diskURL: URL,
                                    auxiliaryStorageURL: URL) -> VZVirtualMachineConfiguration? {

        
        let bootloader = VZMacOSBootLoader()
        let entropy = VZVirtioEntropyDeviceConfiguration()
        let networkDevice = VZVirtioNetworkDeviceConfiguration()
        networkDevice.attachment = VZNATNetworkDeviceAttachment()
        
        let graphics = VZMacGraphicsDeviceConfiguration()
        graphics.displays = [
            VZMacGraphicsDisplayConfiguration(
                widthInPixels: 2880,
                heightInPixels: 1800,
                pixelsPerInch: 220
            )
        ]
        
        let keyboard = VZUSBKeyboardConfiguration()
        let pointingDevice = VZUSBScreenCoordinatePointingDeviceConfiguration()
        
        var storages: [VZStorageDeviceConfiguration] = []
        do {
            let attachment = try VZDiskImageStorageDeviceAttachment(
                url: diskURL,
                readOnly: false
            )
            
//            let attachment_tm = try VZDiskImageStorageDeviceAttachment(
//                url: vmURL.appendingPathComponent("tmback.img"),
//                readOnly: false
//            )
            
            let storage = VZVirtioBlockDeviceConfiguration(attachment: attachment)
//            let storage_tm = VZVirtioBlockDeviceConfiguration(attachment: attachment_tm)
            storages.append(storage)
//            storages.append(storage_tm)
        } catch {
            NSLog("Storage Error: \(error)")
        }

        let soundDevice = VZVirtioSoundDeviceConfiguration()
        let outputStream = VZVirtioSoundDeviceOutputStreamConfiguration()
        outputStream.sink = VZHostAudioOutputStreamSink()
        soundDevice.streams.append(outputStream)
        let inputStream = VZVirtioSoundDeviceInputStreamConfiguration()
        inputStream.source = VZHostAudioInputStreamSource()
        soundDevice.streams.append(inputStream)

        let configuration = VZVirtualMachineConfiguration()
        configuration.bootLoader = bootloader
        
        let platform = VZMacPlatformConfiguration()
        platform.hardwareModel = hardwareModel
        platform.machineIdentifier = machineIdentifier
        
        platform.auxiliaryStorage = try? VZMacAuxiliaryStorage(
            creatingStorageAt: auxiliaryStorageURL,
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
        configuration.audioDevices = [soundDevice]
        return configuration
    }
    
    func guestDidStop(_ virtualMachine: VZVirtualMachine) {
        exit(0)
    }
    
    func virtualMachine(_ virtualMachine: VZVirtualMachine, didStopWithError error: Error) {
    }
}
