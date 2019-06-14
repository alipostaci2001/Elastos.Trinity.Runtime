 /*
  * Copyright (c) 2018 Elastos Foundation
  *
  * Permission is hereby granted, free of charge, to any person obtaining a copy
  * of this software and associated documentation files (the "Software"), to deal
  * in the Software without restriction, including without limitation the rights
  * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  * copies of the Software, and to permit persons to whom the Software is
  * furnished to do so, subject to the following conditions:
  *
  * The above copyright notice and this permission notice shall be included in all
  * copies or substantial portions of the Software.
  *
  * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  * SOFTWARE.
  */
 
 import Foundation

 extension Data {
    private static let hexAlphabet = "0123456789abcdef".unicodeScalars.map { $0 }

    public func hexEncodedString() -> String {
        return String(self.reduce(into: "".unicodeScalars, { (result, value) in
            result.append(Data.hexAlphabet[Int(value/16)])
            result.append(Data.hexAlphabet[Int(value%16)])
        }))
    }
 }

 class AppInstaller {
    
    let pluginWhitelist = [
        "device",
        "networkstatus",
        "splashscreen",
        ];
    
    let urlWhitelist = [
        "http://www.elastos.org/*",
        ];
    
    var appPath: String = "";
    var dataPath: String = "";
    var tempPath: String = "";
    var dbAdapter: ManagerDBAdapter;
    
    init(_ appPath: String, _ dataPath: String, _ tempPath: String, _ dbAdapter: ManagerDBAdapter) {
        self.appPath = appPath;
        self.dataPath = dataPath;
        self.tempPath = tempPath;
        self.dbAdapter = dbAdapter;
    }
    
    func unpackZip(_ srcZip: String, _ destPath: String) -> Bool {
        return SSZipArchive.unzipFile(atPath: srcZip, toDestination: destPath);
    }

    private func sha256(data : Data) -> Data {
        var hash = [UInt8](repeating: 0,  count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0, CC_LONG(data.count), &hash)
        }
        return Data(bytes: hash)
    }

    private func verifyEpkDigest(_ destPath: String) -> Bool {
        let fileManager = FileManager.default

        let dirEnum = fileManager.enumerator(atPath: destPath)
        var fileHashMap = [String: String]()
        var fileListSHA = "EPK-SIGN/FILELIST.SHA not found"
        while let filePath = dirEnum?.nextObject() as? String {
            var isDir : ObjCBool = false
            let fileURL =  NSURL(fileURLWithPath: destPath).appendingPathComponent(filePath)!
            if (fileManager.fileExists(atPath: fileURL.path, isDirectory: &isDir) && !isDir.boolValue) {
                do {
                    let fileData = try Data(contentsOf: fileURL)
                    let hash = sha256(data: fileData)
                    let hashString = hash.hexEncodedString()
                    if (!filePath.starts(with: "EPK-SIGN/")) {
                        fileHashMap[filePath] = hashString
                    } else if (filePath == "EPK-SIGN/FILELIST.SHA") {
                        fileListSHA = String(data: fileData, encoding: .utf8)!
                    }
                }
                catch {
                    print("Failed to hash file " + fileURL.path)
                    return false
                }
            }
        }

        var fileList = ""
        for (k,v) in fileHashMap.sorted(by: {$0.0 < $1.0}) {
            fileList = "\(fileList)\(v) \(k)\n"
        }

        let epkHash = sha256(data: fileList.data(using: .utf8)!).hexEncodedString()
        if (epkHash == fileListSHA) {
            print("Matched EPK digest with \(fileListSHA)")
            return true
        }
        print("Failed to match EPK digest")
        return false;
    }

    private func contentsOf(file fileURL: NSURL) -> String? {
        let fileManager = FileManager.default

        var isDir : ObjCBool = false
        if (fileManager.fileExists(atPath: fileURL.path!, isDirectory: &isDir) && !isDir.boolValue) {
            do {
                let fileData = try Data(contentsOf: fileURL as URL)
                return String(data: fileData, encoding: .utf8)
            }
            catch {
                print("Failed to read file " + fileURL.path!)
                return nil
            }
        }

        print("Failed to read file " + fileURL.path!)
        return nil
    }

    private func verifyEpkSignature(_ destPath: String) -> Bool {
        let publicKey = contentsOf(file: NSURL(fileURLWithPath: destPath).appendingPathComponent("EPK-SIGN/SIGN.PUB")! as NSURL)
        let payload = contentsOf(file: NSURL(fileURLWithPath: destPath).appendingPathComponent("EPK-SIGN/FILELIST.SHA")! as NSURL)
        let signed_payload = contentsOf(file: NSURL(fileURLWithPath: destPath).appendingPathComponent("EPK-SIGN/FILELIST.SIGN")! as NSURL)

        let succeeded = ela_verify_message(publicKey, payload, signed_payload)

        if (succeeded) {
            print("Successfully verified EPK signature")
            print("The public key of the EPK is \(publicKey!)")
        } else {
            print("Failed to verify EPK signature")
        }
        return succeeded
    }

    func deleteAllFiles(_ path: String) throws {
        let fileManager = FileManager.default;
        try fileManager.removeItem(atPath: path)
    }
    
    func copyAssetsFolder(_ src: String, _ dest: String) throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: dest){
            try fileManager.removeItem(atPath: dest)
        }
        
        try fileManager.copyItem(atPath: src, toPath: dest)
    }
    
    func  install(_ appManager: AppManager, _ url: String) throws -> AppInfo? {
        var zipPath = url;
        if (url.hasPrefix("assets://")) {
            zipPath = getAssetsPath(url);
        }
        else if (url.hasPrefix("file://")) {
            let index = url.index(url.startIndex, offsetBy: 7)
            zipPath = String(url[index ..< url.endIndex]);
        }

        let temp = "tmp_" + UUID().uuidString
        let temPath = appPath + temp;
    
        if (!unpackZip(zipPath, temPath)) {
            throw AppError.error("UnpackZip fail!");
        }

        if (!verifyEpkDigest(temPath)) {
            throw AppError.error("verifyEpkDigest fail!");
        }

        if (!verifyEpkSignature(temPath)) {
            throw AppError.error("verifyEpkSignature fail!");
        }

        let fileManager = FileManager.default;
        let ret = fileManager.fileExists(atPath: temPath + "/manifest.json")
        guard ret else {
            try deleteAllFiles(temPath);
            throw AppError.error("manifest.json no exist!");
        }
        
        let info = try parseManifest(temPath + "/manifest.json");
        guard (info != nil && info!.app_id != "" && info!.app_id != "launcher"
                && appManager.getAppInfo(info!.app_id) == nil) else {
            try deleteAllFiles(temPath);
            throw AppError.error("App alreadey exist!");
        }
        
        let path = appPath + info!.app_id;
        if (fileManager.fileExists(atPath: path)) {
            try deleteAllFiles(path);
        }
        
        try fileManager.moveItem(atPath: temPath, toPath: path);
//            let dirs = try! fileManager.contentsOfDirectory(atPath: path);

        info!.built_in = false;
        try appManager.dbAdapter.addAppInfo(info!);
        return info!;
    }
    
    func unInstall(_ info: AppInfo?) throws {
        guard info != nil else {
            throw AppError.error("No such app!");
        }
        
        guard !info!.built_in else {
            throw AppError.error("App is a built in!");
        }
        
        let dataPath = self.dataPath + info!.app_id
        try deleteAllFiles(dataPath);
        try dbAdapter.removeAppInfo(info!);
        let appPath = self.appPath + info!.app_id
        try deleteAllFiles(appPath);
    }
    
    private func isAllowPlugin(_ plugin: String) -> Bool {
        for item in pluginWhitelist {
            if (item == plugin) {
                return true;
            }
        }
        return false;
    }
    
    private func isAllowUrl(_ url: String) -> Bool {
        for item in urlWhitelist {
            if (item == url) {
                return true;
            }
        }
        return false;
    }
    
    private func getMustStrValue(_ json: [String: Any], _ name: String) throws -> String {
        let value = json[name] as? String;
        if (value != nil) {
            return value!
        }
        else {
            throw AppError.error("Parse Manifest.json error: '\(name)' no exist!");
        }
    }
    
    func parseManifest(_ path: String, _ launcher:Bool = false) throws -> AppInfo? {
        let appInfo = AppInfo();
        let url = URL.init(fileURLWithPath: path)
        var value: String?;

        let data = try Data(contentsOf: url);
        let json = try JSONSerialization.jsonObject(with: data,
                                                    options: []) as! [String: Any];
        
        //Must
        appInfo.app_id = try getMustStrValue(json, "id");
        appInfo.version = try getMustStrValue(json, "version");
        appInfo.name = try getMustStrValue(json, "name");
        appInfo.start_url = try getMustStrValue(json, "start_url");
        let range = appInfo.start_url.range(of: "://");
        if range != nil{
            appInfo.remote = true;
        }
        else {
            appInfo.remote = false;
        }

        let icons = json["icons"] as? [Dictionary<String, String>];
        if !launcher {
            if icons != nil {
                for icon in icons! {
                    let src = icon["src"];
                    let sizes = icon["sizes"];
                    let type = icon["type"];
                    appInfo.addIcon(src!, sizes!, type!);
                }
            }
            else {
                throw AppError.error("Parse Manifest.json error: 'icons' no exist!");
            }
        }
        
        //Optional
        value = json["short_name"] as? String;
        if value != nil {
            appInfo.short_name = value!;
        }
        
        value = json["description"] as? String;
        if value != nil {
            appInfo.desc = value!;
        }
        
        value = json["default_locale"] as? String;
        if value != nil {
            appInfo.default_locale = value!;
        }
        
        let author = json["author"] as? [String: Any];
        if author != nil {
            value = author!["name"] as? String;
            if value != nil {
                appInfo.author_name = value!;
            }
            value = author!["email"] as? String;
            if value != nil {
                appInfo.author_email = value!;
            }
        }
        
        var authority = AppInfo.AUTHORITY_NOINIT;
        let plugins = json["plugins"] as? [String];
        if (plugins != nil) {
            for plugin in plugins! {
                authority = AppInfo.AUTHORITY_NOINIT;
                let pluginName = plugin.lowercased();
                if (isAllowPlugin(pluginName)) {
                    authority = AppInfo.AUTHORITY_ALLOW;
                }
                appInfo.addPlugin(pluginName, authority);
            }
        }
        
        let urls = json["urls"] as? [String];
        if (urls != nil) {
            for url in urls! {
                authority = AppInfo.AUTHORITY_NOINIT;
                let urlString = url.lowercased();
                if (isAllowUrl(urlString)) {
                    authority = AppInfo.AUTHORITY_ALLOW;
                }
                appInfo.addUrl(urlString, authority);
            }
        }
        
        
        value = json["background_color"] as? String;
        if value != nil {
            appInfo.background_color = value!;
        }
        
        let theme = json["theme"] as? [String: Any];
        if (theme != nil) {
            value = theme!["display"] as? String;
            if value != nil {
                appInfo.theme_display = value!;
            }
            value = theme!["color"] as? String;
            if value != nil {
                appInfo.theme_color = value!;
            }

            value = theme!["font_name"] as? String;
            if value != nil {
                appInfo.theme_font_name = value!;
            }

            value = theme!["font_color"] as? String;
            if value != nil {
                appInfo.theme_font_color = value!;
            }
        }
        
        appInfo.install_time = Int64(Date().timeIntervalSince1970);
        appInfo.launcher = launcher;
        
        let fileManager = FileManager.default
        if (!fileManager.fileExists(atPath: dataPath + appInfo.app_id)) {
            do {
                try fileManager.createDirectory(atPath: dataPath + appInfo.app_id, withIntermediateDirectories: true, attributes: nil)
            }
            catch let error {
                print("Make dataPath error: \(error)");
            }
        }
        if (!fileManager.fileExists(atPath: tempPath + appInfo.app_id)) {
            do {
                try fileManager.createDirectory(atPath: tempPath + appInfo.app_id, withIntermediateDirectories: true, attributes: nil)
            }
            catch let error {
                print("Make tempPath error: \(error)");
            }
        }


        return appInfo;
    }
 }
 
