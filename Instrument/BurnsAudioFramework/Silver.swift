//
//  File.swift
//  iOSSpectrumApp
//
//  Created by tom on 2019-06-30.
//

import Foundation
import UIKit

open class Silver {
    static var REGISTRATION_URL = "https://silver.burns.ca/token"
    
    public enum Status {
        case Authorized(token: String)
        case Unauthorized
    }
    
    public class func report(status: Status) {
        guard let uuid = UIDevice.current.identifierForVendor?.uuidString else {
            NSLog("Could not get identifierForVendor")
            return
        }
        
        guard case .Authorized(let token) = status else {
            NSLog("Unauthorized")
            return
        }
        
        print(uuid)
        
        let url = URL(string: REGISTRATION_URL)!
        var request = URLRequest(url: url)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        let parameters: [String: Any] = [
            "token": token,
            "device": uuid,
            "app": "Spectrum"
        ]
        
        request.httpBody = parameters.percentEscaped().data(using: .utf8)
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data,
                let response = response as? HTTPURLResponse,
                error == nil else {                                              // check for fundamental networking error
                    print("error", error ?? "Unknown error")
                    return
            }
            
            guard (200 ... 299) ~= response.statusCode else {                    // check for http errors
                print("statusCode should be 2xx, but is \(response.statusCode)")
                print("response = \(response)")
                return
            }
            
            let responseString = String(data: data, encoding: .utf8)
            print("responseString = \(responseString ?? "empty")")
        }
        
        task.resume()
    }
}

extension Dictionary {
    func percentEscaped() -> String {
        return map { (key, value) in
            let escapedKey = "\(key)".addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? ""
            let escapedValue = "\(value)".addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? ""
            return escapedKey + "=" + escapedValue
            }
            .joined(separator: "&")
    }
}

extension CharacterSet {
    static let urlQueryValueAllowed: CharacterSet = {
        let generalDelimitersToEncode = ":#[]@" // does not include "?" or "/" due to RFC 3986 - Section 3.4
        let subDelimitersToEncode = "!$&'()*+,;="
        
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "\(generalDelimitersToEncode)\(subDelimitersToEncode)")
        return allowed
    }()
}
