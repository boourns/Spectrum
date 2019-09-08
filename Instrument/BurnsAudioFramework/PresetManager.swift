//
//  PresetManager.swift
//  iOSSpectrumApp
//
//  Created by tom on 2019-08-28.
//

import Foundation
import AVFoundation
import UIKit

public enum PresetSaveResult {
    case success(activityViewController: UIActivityViewController)
    case error(message: String)
}

public struct PresetDetails {
    let filenameSuffix: String
    let name: String
    let group: String
    let directoryName: String
    
    func createPresetDirectory() {
        let url = presetURL()
        
        if !FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.createDirectory(atPath: url.path, withIntermediateDirectories: true, attributes: nil)
            } catch {
                NSLog("Couldn't create document directory")
            }
        }
    }
    
    func presetURL() -> URL {
        let baseUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)!
        return baseUrl.appendingPathComponent(directoryName, isDirectory: true)
    }
    
    func presets() -> [URL] {
//        let enumerator = FileManager.default.enumerator(atPath: presetURL().path)
//
//        let filePaths = enumerator?.allObjects as! [String]
//        let txtFilePaths = filePaths.filter{$0.contains(".txt")}
//        for txtFilePath in txtFilePaths{
//            //Here you get each text file path present in folder
//            //Perform any operation you want by using its path
//        }
        return []
    }
}

open class PresetImporter {
    let details: [PresetDetails]
    
    public init(details: [PresetDetails]) {
        self.details = details
    }
    
    public func createPresetDirectories() {
        for detail in details {
            detail.createPresetDirectory()
        }
    }
    
    public func importPreset(url: URL) -> Bool {
        guard let detail = details(forUrl: url) else { return false }
        guard loadPreset(url: url) != nil else { return false }
        
        
        return true
    }
    
    public func loadPreset(url: URL) -> [String: Any]? {
        guard let detail = details(forUrl: url) else { return nil }
        
        do {
            let data = try Data(contentsOf: url)
            
            guard let preset = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [String:Any] else {
                return nil
            }
            
            guard preset["name"] as? String == detail.name else {
                return nil
            }
            
            return preset["state"] as? [String: Any]
        } catch {
            print("Failed to read preset \(url.absoluteURL)")
            return nil
        }
    }
    
    private func details(forUrl url: URL) -> PresetDetails? {
        return details.first(where: { $0.filenameSuffix == url.pathExtension })
    }
}

open class PresetExporter {
    let audioUnit: AUAudioUnit
    let name: String
    
    public init(audioUnit: AUAudioUnit, name: String) {
        self.audioUnit = audioUnit
        self.name = name
    }
    
    public func saveAndPresent(filename: String) -> PresetSaveResult {
        guard let state = audioUnit.fullState else { return .error(message: "Failed to get state from AU") }
        
        let url = URL.init(fileURLWithPath: filename, relativeTo: URL.init(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true))

        let preset: [String:Any] = [
            "name": name,
            "preset": state
        ]
        
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: preset, requiringSecureCoding: false)
            try data.write(to: url)
        } catch {
            return .error(message: "Could not write preset to disk")
        }
                
        let activity = UIActivityViewController(activityItems: [NSURL(fileURLWithPath: url.absoluteString)], applicationActivities: nil)
        activity.completionWithItemsHandler = { activityType, completed, items, error in
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                print("Failed to delete temporary file!")
            }
        }
        
        return .success(activityViewController: activity)
    }
}
