//
//  TitleBarPlugin.swift
//  elastOS
//
//  Created by Benjamin Piette on 05/03/2020.
//

import Foundation

@objc(TitleBarPlugin)
class TitleBarPlugin : TrinityPlugin {
    func success(_ command: CDVInvokedUrlCommand) {
        let result = CDVPluginResult(status: CDVCommandStatus_OK)
        
        self.commandDelegate.send(result, callbackId: command.callbackId)
    }
    
    func error(_ command: CDVInvokedUrlCommand, _ retAsString: String) {
        let result = CDVPluginResult(status: CDVCommandStatus_ERROR,
                                     messageAs: retAsString);
        
        self.commandDelegate.send(result, callbackId: command.callbackId)
    }
    
    private func getTitleBar() -> TitleBarView {
        let viewController = AppManager.getShareInstance().getViewControllerById(self.appId);
        return viewController!.getTitlebar();
    }
    
    @objc func showActivityIndicator(_ command: CDVInvokedUrlCommand) {
        let activityIndicatoryType = command.arguments[0] as! Int
                
        DispatchQueue.main.async {
            self.getTitleBar().showActivityIndicator(activityType: TitleBarActivityType.init(rawValue: activityIndicatoryType) ?? .OTHER)
        }
        
        self.success(command)
    }
    
    @objc func hideActivityIndicator(_ command: CDVInvokedUrlCommand) {
        let activityIndicatoryType = command.arguments[0] as! Int
                
        DispatchQueue.main.async {
            self.getTitleBar().hideActivityIndicator(activityType: TitleBarActivityType.init(rawValue: activityIndicatoryType) ?? .OTHER)
        }
        
        self.success(command)
    }
    
    @objc func setTitle(_ command: CDVInvokedUrlCommand) {
        var title: String? = nil
        if command.arguments.count > 0 {
            title = command.arguments[0] as? String
        }
        
        getTitleBar().setTitle(title)
        
        self.success(command)
    }
    
    @objc func setBackgroundColor(_ command: CDVInvokedUrlCommand) {
        let hexColor = command.arguments[0] as? String ?? "#000000"
        
        if (getTitleBar().setBackgroundColor(hexColor)) {
            self.success(command)
        } else {
            self.error(command, "Invalid color \(hexColor)")
        }
    }
    
    @objc func setForegroundMode(_ command: CDVInvokedUrlCommand) {
        let modeAsInt = command.arguments[0] as! Int
        
        getTitleBar().setForegroundMode(TitleBarForegroundMode(rawValue: modeAsInt) ?? .LIGHT)
        
        self.success(command)
    }
    
    @objc func setBehavior(_ command: CDVInvokedUrlCommand) {
        let behaviorAsInt = command.arguments[0] as! Int
        
        getTitleBar().setBehavior(TitleBarBehavior(rawValue: behaviorAsInt) ?? .DEFAULT)
        
        self.success(command)
    }
    
    @objc func setNavigationMode(_ command: CDVInvokedUrlCommand) {
        let modeAsInt = command.arguments[0] as! Int
        
        getTitleBar().setNavigationMode(TitleBarNavigationMode(rawValue: modeAsInt) ?? .NONE)
        
        self.success(command)
    }
    
    @objc func setupMenuItems(_ command: CDVInvokedUrlCommand) {
        let menuItemsJson = command.arguments[0] as! [Dictionary<String, String>]
        
        // Convert plugin data to clean model
        var menuItems: [TitleBarMenuItem] = []
        for mi in menuItemsJson {
            if let menuItem = menuItemFromJsonObject(jsonObj: mi) {
                menuItems.append(menuItem)
            }
        }
        
        getTitleBar().setupMenuItems(menuItems: menuItems) { selectedMenuItem in
            // An item of the menu was clicked by the user
            let result = try! CDVPluginResult(status: CDVCommandStatus_OK, messageAs: selectedMenuItem.toJson() as? [AnyHashable : Any])
            result!.setKeepCallbackAs(true)
            self.commandDelegate.send(result, callbackId: command.callbackId)
        }
    }
    
    private func menuItemFromJsonObject(jsonObj: Dictionary<String, String>) -> TitleBarMenuItem? {
        if !jsonObj.keys.contains("key") || !jsonObj.keys.contains("iconPath") || !jsonObj.keys.contains("title") {
            return nil
        }
        
        let menuItem = TitleBarMenuItem(
            key: jsonObj["key"]!,
            iconPath: jsonObj["iconPath"]!,
            title: jsonObj["title"]!)
        
        return menuItem
    }
}
