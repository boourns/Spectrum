/*
	Copyright (C) 2016 Apple Inc. All Rights Reserved.
	See LICENSE.txt for this sample’s licensing information
	
	Abstract:
	Main entry point to the application.
*/

import UIKit
import UserNotifications
import BurnsAudioCore

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    // MARK: Properties
	var window: UIWindow?
    var silverAppName: String?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window!.rootViewController = ViewController()
        window!.makeKeyAndVisible()
        
        //configurePushNotifications()
        
        if let notification = launchOptions?[.remoteNotification] as? [String: AnyObject],
                   let aps = notification["aps"] as? [String: AnyObject],
                   let link = aps["link"] as? String,
                   let url = URL(string: link) {
                       UIApplication.shared.open(url)
               }
               
        UNUserNotificationCenter.current().delegate = self

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
        
        Silver.report(appName: silverAppName!, status: .Authorized(token: token))
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register: \(error)")
        
        Silver.report(appName: silverAppName!, status: .Unauthorized)
    }
    
    // This method will be called when app received push notifications in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void)
    {
        completionHandler([.alert, .badge, .sound])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            if let notification =  response.notification.request.content.userInfo as? [String: AnyObject], let aps = notification["aps"] as? [String: AnyObject],
                let link = aps["link"] as? String,
                let url = URL(string: link) {
                    UIApplication.shared.open(url)
            }
        }
    }
    
    func configurePushNotifications() {
        guard let appName = Bundle.main.infoDictionary?["SILVER_APPNAME"] as? String,
            let apiEndpoint = Bundle.main.infoDictionary?["SILVER_API_ENDPOINT"] as? String else {
                fatalError("Add SILVER_APPNAME and SILVER_API_ENDPOINT to Info.plist")
        }
        
        Silver.setRegistrationUrl(apiEndpoint)
        silverAppName = appName
        
        registerForPushNotifications()
    }
}

