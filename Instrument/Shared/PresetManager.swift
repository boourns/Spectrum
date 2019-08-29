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
    case success
    case error(message: String)
}

open class PresetManager {
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
        
        let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        activity.completionWithItemsHandler = { activityType, completed, items, error in
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                print("Failed to delete temporary file!")
            }
        }
        
        return .success
    }
}
