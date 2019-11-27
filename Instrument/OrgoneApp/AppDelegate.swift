//
//  ViewController.swift
//  OrgoneApp
//
//  Created by tom on 2019-09-07.
//

import UIKit
import UserNotifications
import BurnsAudio

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    // MARK: Properties
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window!.rootViewController = ViewController()
        window!.makeKeyAndVisible()
        
        registerForPushNotifications()
        
        if let notification = launchOptions?[.remoteNotification] as? [String: AnyObject],
            let aps = notification["aps"] as? [String: AnyObject],
            let link = aps["link"] as? String,
            let url = URL(string: link) {
            UIApplication.shared.open(url)
        }
        
        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return true
    }
    
    func registerForPushNotifications() {
        if #available(iOS 12, *) {
            UNUserNotificationCenter.current() // 1
                .requestAuthorization(options: [.alert, .sound, .provisional]) { [weak self] granted, error in
                    print("Permission granted: \(granted)")
                    guard granted else { return }
                    self?.getNotificationSettings()
            }
        } else {
            UNUserNotificationCenter.current() // 1
                .requestAuthorization(options: [.alert, .sound]) { [weak self] granted, error in
                    print("Permission granted: \(granted)")
                    guard granted else { return }
                    self?.getNotificationSettings()
            }
        }
    }
    
    func getNotificationSettings() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("Notification settings: \(settings.authorizationStatus.rawValue)")
            if #available(iOS 12, *) {
                guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
            } else {
                guard settings.authorizationStatus == .authorized else { return }
            }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("Device Token: \(token)")
        Silver.report(status: .Authorized(token: token))
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register: \(error)")
        Silver.report(status: .Unauthorized)
    }
}

