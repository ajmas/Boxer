// Copyright (c) 2019, OpenEmu Team
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//     * Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above copyright
//       notice, this list of conditions and the following disclaimer in the
//       documentation and/or other materials provided with the distribution.
//     * Neither the name of the OpenEmu Team nor the
//       names of its contributors may be used to endorse or promote products
//       derived from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY OpenEmu Team ''AS IS'' AND ANY
// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL OpenEmu Team BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import Foundation

@objc
public class BXShadersModel : NSObject {
    // MARK: Notifications
    
    @objc static let shaderModelCustomShadersDidChange = Notification.Name("BXShaderModelCustomShadersDidChangeNotification")
    
    enum Preferences {
        case global
        case system(String)
        
        var key: String {
            get {
                switch self {
                case .global:
                    return "videoShader"
                case .system(let identifier):
                    return "videoShader.\(identifier)"
                }
            }
        }
    }
    
    @objc
    public static var shared : BXShadersModel = {
        return BXShadersModel()
    }()
    
    private var systemShaders: [BXShaderModel]
    private var customShaders: [BXShaderModel]
    
    override init() {
        systemShaders = BXShadersModel.loadSystemShaders()
        customShaders = BXShadersModel.loadCustomShaders()
        super.init()
    }
    
    @objc
    public func reload() {
        customShaders       = BXShadersModel.loadCustomShaders()
        _allShaderNames     = nil
        _customShaderNames  = nil
        NotificationCenter.default.post(name: BXShadersModel.shaderModelCustomShadersDidChange, object: nil)
    }
    
    private var _systemShaderNames: [String]?
    
    @objc
    public var systemShaderNames: [String] {
        if _systemShaderNames == nil {
            _systemShaderNames = systemShaders.map { $0.name }
        }
        return _systemShaderNames!
    }

    private var _customShaderNames: [String]?
    
    @objc
    public var customShaderNames: [String] {
        if _customShaderNames == nil {
            _customShaderNames = customShaders.map { $0.name }
        }
        return _customShaderNames!
    }

    private var _allShaderNames: [String]?
    
    @objc
    public var allShaderNames: [String] {
        if _allShaderNames == nil {
            
        }
        return _allShaderNames!
    }
    
    @objc
    public var defaultShader: BXShaderModel {
        get {
            if let name = UserDefaults.standard.string(forKey: Preferences.global.key),
                let shader = self[name] {
                return shader
            }
            
            return self["Pixellate"]!
        }
        
        set {
            UserDefaults.standard.set(newValue.name, forKey: Preferences.global.key)
        }
    }
    
    @objc
    public func shader(withName name: String) -> BXShaderModel? {
        return self[name]
    }
    
    @objc
    public func shader(forSystem identifier: String) -> BXShaderModel? {
        guard let name = UserDefaults.standard.string(forKey: Preferences.system(identifier).key) else {
            return defaultShader
        }
        return self[name]
    }
    
    @objc
    public func shader(forURL url: URL) -> BXShaderModel? {
        return BXShaderModel(url: url)
    }
    
    subscript(name: String) -> BXShaderModel? {
        return systemShaders.first(where: { $0.name == name }) ?? customShaders.first(where: { $0.name == name })
    }
    
    // MARK: - helpers
    
    private static func loadSystemShaders() -> [BXShaderModel] {
        if let path = Bundle.main.resourcePath {
            let url = URL(fileURLWithPath: path, isDirectory: true).appendingPathComponent("Shaders", isDirectory: true)
            let urls = urlsForShaders(at: url)
            return urls.map(BXShaderModel.init(url:))
        }
        return []
    }
    
    private static func loadCustomShaders() -> [BXShaderModel] {
        var shaders = [BXShaderModel]()
        
        let paths = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)
        for path in paths {
            let subpath = URL(fileURLWithPath: path, isDirectory: true).appendingPathComponent("Boxer").appendingPathComponent("Shaders")
            let urls    = urlsForShaders(at: subpath)
            if urls.count > 0 {
                shaders.append(contentsOf: urls.map(BXShaderModel.init(url:)))
            }
        }
        
        return shaders
    }

    static func urlsForShaders(at url: URL) -> [URL] {
        var res = [URL]()
        
        guard
            let urls = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsSubdirectoryDescendants)
            else { return [] }
        
        let dirs = urls.filter({ (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false })
        for dir in dirs {
            guard
                let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
                else { continue }
            if let slangp = files.first(where: { $0.pathExtension == "slangp" }) {
                // we have a file!
                res.append(slangp)
            }
        }
        
        return res
    }
    
    @objc
    public lazy var userShadersPath: URL? = {
        guard let path = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false) else { return nil }
        return path.appendingPathComponent("Boxer", isDirectory: true).appendingPathComponent("Shaders", isDirectory: true)
    }()
    
    private static func loadShaders() -> [BXShaderModel] {
        var shaders = [BXShaderModel]()
        
        if let path = Bundle.main.resourcePath {
            let url = URL(fileURLWithPath: path, isDirectory: true).appendingPathComponent("Shaders", isDirectory: true)
            let urls = Self.urlsForShaders(at: url)
            shaders = urls.map(BXShaderModel.init(url:))
        }
        
        let paths = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)
        for path in paths {
            let subpath = URL(fileURLWithPath: path, isDirectory: true).appendingPathComponent("Boxer").appendingPathComponent("Shaders")
            let urls    = Self.urlsForShaders(at: subpath)
            if urls.count > 0 {
                shaders.append(contentsOf: urls.map(BXShaderModel.init(url:)))
            }
        }
        
        return shaders
    }
    
    // MARK: - Shader Model

    @objc(BXShaderModel)
    @objcMembers
    public class BXShaderModel : NSObject {
        enum Params {
            case global(String)
            case system(String, String)
            
            var key: String {
                get {
                    switch self {
                    case .global(let shader):
                        return "videoShader.\(shader).params"
                    case .system(let shader, let identifier):
                        return "videoShader.\(identifier).\(shader).params"
                    }
                }
            }
        }
        
        public var name: String
        public var url: URL
        
        init(url: URL) {
            self.name = url.deletingLastPathComponent().lastPathComponent
            self.url  = url
        }
        
        @objc
        public func parameters(forIdentifier identifier: String) -> [String: Double]? {
            if let state = UserDefaults.standard.string(forKey: Params.system(self.name, identifier).key) {
                var res = [String:Double]()
                for param in state.split(separator: ";") {
                    let vals = param.split(separator: "=")
                    if let d = Double(vals[1]) {
                        res[String(vals[0])] = d
                    }
                }
                return res
            }
            
            return nil
        }
        
        override public var description: String {
            return self.name
        }
        
        public override var debugDescription: String {
            return "\(name) \(url.absoluteString)"
        }
    }
}
