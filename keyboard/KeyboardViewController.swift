//
//  KeyboardViewController.swift
//  keyboard
//
//  Created by Булыгин Лев Эдуардович on 05/02/2019.
//  Copyright © 2019 Lev Bulygin. All rights reserved.
//

import UIKit

enum Orientation: String {
    case portrait
    case landscape
}

struct Colors {
    // background
    static let lightModeBackground = UIColor(red: 208/255, green: 211/255, blue: 216/255, alpha: 1)
    static let darkModeBackground = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.01)
    // suggestions
    static let lightModeSuggestionDivider = UIColor(red: 177/255, green: 180/255, blue: 186/255, alpha: 1.0)
    static let darkModeSuggestionDivider = UIColor(white: 1.0, alpha: 0.06)
    // keys
    static let lightModeKeyText = UIColor.black
    static let lightModeKeyBackground = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
    static let lightModeSpecialKeyBackground = UIColor(red: 0.67, green: 0.71, blue: 0.75, alpha: 1.0)
    static let darkModeKeyText = UIColor.white
    static let darkModeKeyBackground = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.30)
    static let darkModeSpecialKeyBackground = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.12)
    static let disabledKeyText = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.5)
    static let KeyShadow = UIColor(red: 0.1, green: 0.15, blue: 0.06, alpha: 0.36).cgColor
}

enum SavedDefaults: String {
    case KeyLayout
    case KeyLabels
}

enum KeyboardLayout: String {
    case Alphabetical
    case MappingToQWERTY
    
    func toUrdu() -> String {
        switch self {
        case .Alphabetical:
            return "Alphabetical"
        case .MappingToQWERTY:
            return "Change to QWERTY"
        }
    }
}

enum KeyboardColorMode: String {
    case Light
    case Dark
}

enum KeyboardMode: String {
    case primary
    case secondary
}

enum KeyboardCase: String {
    case lowercase
    case uppercase
}

enum KeyboardSpecial: String {
    case numbers
    case symbols
}

class KeyboardViewController: UIInputViewController {
    
    var keysView: UIView!
    var keys: [Key] = []
    var layout: KeyboardLayout!
    var contextualFormsEnabled: Bool!
    var keyboardSelectionKey: Key?
    var spaceKey: Key?
    var zeroWidthNonJoinerKey: Key?
    var settingsKey: Key?
    var letterKeys: [String: Key] = [:]
    var popUpHeightHang: CGFloat!
    var keysViewHeight: CGFloat!
    var viewHeight: CGFloat!
    var heightConstraint: NSLayoutConstraint?
    var touchPoints: [CGPoint] = []
    var keyboardMode = KeyboardMode.primary
    var keyboardCase = KeyboardCase.lowercase
    var keyboardSpecial = KeyboardSpecial.numbers
    var backspaceTimer: Timer?
    var backspaceCount = 0
    var activeKey: Key?

    // @IBOutlet var nextKeyboardButton: UIButton!
    
    /*
    override func updateViewConstraints() {
        super.updateViewConstraints()
        
        // Add custom view sizing constraints here
    }
 */
    
    override func viewDidLoad() {
        
        // boilerplate setup
        super.viewDidLoad()
        
        
        /*
        
        self.nextKeyboardButton = UIButton(type: .system)
        
        self.nextKeyboardButton.setTitle(NSLocalizedString("Next Keyboard", comment: "Title for 'Next Keyboard' button"), for: [])
        self.nextKeyboardButton.sizeToFit()
        self.nextKeyboardButton.translatesAutoresizingMaskIntoConstraints = false
        
        self.nextKeyboardButton.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
        
        self.view.addSubview(self.nextKeyboardButton)
        
        self.nextKeyboardButton.leftAnchor.constraint(equalTo: self.view.leftAnchor).isActive = true
        self.nextKeyboardButton.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true
        */
        
        
        // view setup
        self.view.isUserInteractionEnabled = true
        self.view.isMultipleTouchEnabled = false
        self.view.backgroundColor = Colors.lightModeBackground
        
        // set up key views
        self.keysView = UIView(frame: CGRect.zero)
        self.keysView.isUserInteractionEnabled = true
        self.keysView.isMultipleTouchEnabled = false
        self.view.addSubview(self.keysView)
        
        // add transparent view so autolayout works, have to enable user interaction so superview's user interaction also works
        let transparentView = UIView.init(frame: CGRect(
            origin: CGPoint.init(x: 0, y: 0),
            size: CGSize.init(width: 0, height: 0)))
        self.view.addSubview(transparentView)
        transparentView.isUserInteractionEnabled = true
        transparentView.translatesAutoresizingMaskIntoConstraints = false;
        transparentView.bottomAnchor.constraint(equalTo: inputView!.layoutMarginsGuide.bottomAnchor, constant: -4.0).isActive = true
        
        // read settings
        self.readSettings()
        self.updateViewConstraints()
        
        // set up buttons
        self.setUpKeys()
        
        
    }
    
    
    func readSettings() {
        
        // layout
        if let defaultLayout = UserDefaults.standard.value(forKey: SavedDefaults.KeyLayout.rawValue) {
            self.layout = KeyboardLayout.init(rawValue: defaultLayout as! String)
        } else {
            self.layout = KeyboardLayout.Alphabetical
            UserDefaults.standard.set(self.layout.rawValue, forKey: SavedDefaults.KeyLayout.rawValue)
        }
        
        // labels
        if let defaultLabels = UserDefaults.standard.value(forKey: SavedDefaults.KeyLabels.rawValue) {
            self.contextualFormsEnabled = (defaultLabels as! Bool)
        } else {
            self.contextualFormsEnabled = true
            UserDefaults.standard.set(self.contextualFormsEnabled, forKey: SavedDefaults.KeyLabels.rawValue)
        }
    }
    
    func setUpKeys() {
        
        // filepath
        
        //print(self.layout.rawValue)
        // let fileName = self.layout.rawValue + "-keys"
        let fileName = "default-keys"
        let path = Bundle.main.path(forResource: fileName, ofType: "plist")
        
        // read plist
        if let dict = NSDictionary(contentsOfFile: path!) {
            // create key for every item in dictionary
            for (key, value) in dict {
                var info = value as! Dictionary<String, Any>
                // info["label"] = "a"
                addKey(name: key as! String,
                       type: Key.KeyType(rawValue: info["type"] as! String)!,
                       label: info["label"] as! String,
                       neighbors: info["neighbors"] as? Array<String>)
            }
        }
    }
    
    func addKey(name: String, type: Key.KeyType, label: String, neighbors: Array<String>?) {
        
        let key = Key(name: name, type: type, label: label, contextualFormsEnabled: self.contextualFormsEnabled, keyboardViewController: self, neighbors: neighbors)
        
        // let key = Key(name: name, type: type, label: label, contextualFormsEnabled: self.contextualFormsEnabled, keyboardViewController: self, neighbors: neighbors)
        self.keys.append(key)
        self.keysView.addSubview(key)
        
        // store references
        switch key.type {
        case Key.KeyType.Space:
            self.spaceKey = key
        case Key.KeyType.ZeroWidthNonJoiner:
            self.zeroWidthNonJoinerKey = key
        case Key.KeyType.Settings:
            self.settingsKey = key
        case Key.KeyType.Letter:
            self.letterKeys[key.name] = key
        case Key.KeyType.KeyboardSelection:
            self.keyboardSelectionKey = key
        default:
            break
        }
    }
    
    override func textWillChange(_ textInput: UITextInput?) {
        // The app is about to change the document's contents. Perform any preparation here.
    }
    
    override func textDidChange(_ textInput: UITextInput?) {
        // The app has just changed the document's contents, the document context has been updated.
        
        var textColor: UIColor
        let proxy = self.textDocumentProxy
        if proxy.keyboardAppearance == UIKeyboardAppearance.dark {
            textColor = UIColor.white
        } else {
            textColor = UIColor.black
        }
        // self.nextKeyboardButton.setTitleColor(textColor, for: [])
    }
    
    override func viewWillLayoutSubviews() {
        self.layoutKeys()
    }
    
    override func updateViewConstraints() {
        self.setDimensions()
        self.updateHeightConstraint()
        super.updateViewConstraints()
    }
    
    func updateHeightConstraint() {
        if (self.heightConstraint == nil) {
            self.heightConstraint = NSLayoutConstraint(item: self.view,
                                                       attribute: NSLayoutConstraint.Attribute.height,
                                                       relatedBy: NSLayoutConstraint.Relation.equal,
                                                       toItem: nil,
                                                       attribute: NSLayoutConstraint.Attribute.notAnAttribute,
                                                       multiplier: 1.0,
                                                       constant: self.viewHeight)
            self.heightConstraint?.priority = UILayoutPriority(rawValue: 999.0)
            self.heightConstraint?.isActive = true
        } else {
            self.heightConstraint!.constant = self.viewHeight
        }
        self.view.addConstraint(heightConstraint!)
    }
    
    func setDimensions() {
        // let layoutFileName = self.layout.rawValue + "-" + self.getDeviceType() + "-meta"
        let layoutFileName = self.getDeviceType() + "-meta"
        // layoutFileName = "small-phone-portrait-meta"
        //let layoutFileName = "standard-phone-portrait-meta"
        let path = Bundle.main.path(forResource: layoutFileName, ofType: "plist")
        if let dict = NSDictionary(contentsOfFile: path!) {
            self.keysViewHeight = dict["primary-height"] as? CGFloat
            self.popUpHeightHang = dict["pop-up-height-hang"] as? CGFloat
            self.viewHeight = self.keysViewHeight
        }
        self.keysView.frame = CGRect(origin: CGPoint.init(x: 0, y: 0),
                                     size: CGSize.init(width: UIScreen.main.bounds.width, height: self.keysViewHeight))
    }
    
    func layoutKeys() {
        // get layout file
        var layoutFileName = self.getDeviceType() + "-" + self.keyboardMode.rawValue
        // layoutFileName = "small-phone-portrait-primary-lowercase.plist"
        // var layoutFileName = "standard-phone-portrait-" + self.keyboardMode.rawValue
        
        if self.keyboardMode.rawValue == "primary" {
            layoutFileName = layoutFileName + "-" + self.keyboardCase.rawValue
        }
        
        if self.keyboardMode.rawValue == "secondary" {
            layoutFileName = layoutFileName + "-" + self.keyboardSpecial.rawValue
        }
        
        // read plist and update layout
        let path = Bundle.main.path(forResource: layoutFileName, ofType: "plist")
        if let dict = NSDictionary(contentsOfFile: path!) {
            for key in self.keys {
                if let info = dict[key.name] as? Dictionary<String, Double> {
                    if key.name.count < 2 {
                        key.setLayout(x: info["x"]!, y: info["y"]!, width: info["width"]!, height: info["height"]!)
                    } else {
                        key.setLayout(x: info["x"]!, y: info["y"]!, width: info["width"]!, height: info["height"]!, button_font: 0.4)
                    }
                    
                } else {
                    key.hide()
                }
            }
        }
    }
    
    func isPhone() -> Bool {
        return getDeviceType().contains("phone")
    }

    func getDeviceType() -> String {
        
        // get modelName
        var modelName: String
        if TARGET_OS_SIMULATOR != 0 {
            modelName = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? ""
        } else {
            var size = 0
            sysctlbyname("hw.machine", nil, &size, nil, 0)
            var machine = [CChar](repeating: 0, count: size)
            sysctlbyname("hw.machine", &machine, &size, nil, 0)
            modelName = String(cString: machine)
        }
        
        // switch model name to model type
        var type: String
        switch modelName {
        case "iPhone3,1", "iPhone3,2", "iPhone3,3", "iPhone4,1", "iPhone5,1", "iPhone5,2", "iPhone5,3", "iPhone5,4", "iPhone6,1", "iPhone6,2", "iPhone8,4":
            type = "small-phone"
        case "iPhone7,2", "iPhone8,1", "iPhone9,1", "iPhone9,3", "iPhone10,1", "iPhone10,4":
            type = "standard-phone"
        case "iPhone7,1", "iPhone8,2", "iPhone9,2", "iPhone9,4", "iPhone10,2", "iPhone10,5":
            type = "plus-phone"
        case "iPhone10,3", "iPhone10,6", "iPhone11,2":
            type = "X-phone"
        case "iPhone11,8", "iPhone11,4", "iPhone11,6":
            type = "XR-phone"
        case "iPad2,1", "iPad2,2", "iPad2,3", "iPad2,4", "iPad3,1", "iPad3,2", "iPad3,3", "iPad3,4", "iPad3,5", "iPad3,6", "iPad4,1", "iPad4,2", "iPad4,3", "iPad5,3", "iPad5,4", "iPad6,11", "iPad6,12",  "iPad7,5", "iPad7,6", "iPad2,5", "iPad2,6", "iPad2,7", "iPad4,4", "iPad4,5", "iPad4,6", "iPad4,7", "iPad4,8", "iPad4,9", "iPad5,1", "iPad5,2", "iPad6,3", "iPad6,4", "iPad8,1", "iPad8,2", "iPad8,3", "iPad8,4", "iPad8,5", "iPad8,6", "iPad8,7", "iPad8,8":
            type = "standard-tablet"
        case "iPad6,7", "iPad6,8", "iPad7,1", "iPad7,2":
            type = "large-tablet"
        case "iPad7,3", "iPad7,4":
            type = "medium-tablet"
        default:
            type = "unknown"
        }
        
        type += "-" + getCurrentOrientation().rawValue
        return type
    }
    
    func getCurrentOrientation() -> Orientation {
        if UIScreen.main.bounds.size.width < UIScreen.main.bounds.size.height {
            return Orientation.portrait
        } else {
            return Orientation.landscape
        }
    }
    
    func switchKeyboardMode() {
        if self.keyboardMode == KeyboardMode.primary {
            self.keyboardMode = KeyboardMode.secondary
        } else {
            self.keyboardMode = KeyboardMode.primary
        }
        self.layoutKeys()
    }
    
    func switchToPrimaryMode() {
        if self.keyboardMode != KeyboardMode.primary {
            self.switchKeyboardMode()
        }
    }
    
    func switchKeyboardCase() {
        if self.keyboardCase == KeyboardCase.lowercase {
            self.keyboardCase = KeyboardCase.uppercase
        } else {
            self.keyboardCase = KeyboardCase.lowercase
        }
        self.layoutKeys()
    }
    
    func switchKeyboardSpecial() {
        if self.keyboardSpecial == KeyboardSpecial.numbers {
            self.keyboardSpecial = KeyboardSpecial.symbols
        } else {
            self.keyboardSpecial = KeyboardSpecial.numbers
        }
        self.layoutKeys()
    }
    
    func startBackspace() {
        if self.textDocumentProxy.documentContextBeforeInput?.count == 0 { return }
        if self.backspaceTimer == nil || !self.backspaceTimer!.isValid {
            self.textDocumentProxy.deleteBackward()
            self.backspaceTimer = Timer.scheduledTimer(timeInterval: 0.15, target: self, selector: #selector(backspaceTimerFired(timer:)), userInfo: nil, repeats: true)
        }
    }
    
    func stopBackspace() {
        self.backspaceTimer?.invalidate()
        self.backspaceCount = 0
    }
    
    @objc func backspaceTimerFired(timer: Timer) {
        if (self.backspaceCount < 15) {
            self.textDocumentProxy.deleteBackward()
            self.backspaceCount += 1
        } else {
            self.textDocumentProxy.deleteBackward()
            if let words = self.textDocumentProxy.documentContextBeforeInput?.components(separatedBy: " ") {
                let charsToDelete = words.last!.count + 1
                for _ in 1...charsToDelete { self.textDocumentProxy.deleteBackward() }
            }
            if self.textDocumentProxy.documentContextBeforeInput?.count == 0 { self.stopBackspace() }
        }
    }
    
    func highlightNearestKey(touchPoint: CGPoint) {
        if touchPoint.y < 0 {
            self.activeKey?.unHighlight()
            self.activeKey = nil
            return
        }
        let nearestKey = getNearestKeyTo(touchPoint)
        if nearestKey != self.activeKey {
            self.activeKey?.unHighlight()
            self.activeKey = nearestKey
            self.activeKey?.highlight()
        }
    }
    
    func getNearestKeyTo(_ point: CGPoint) -> Key? {
        var minDist = CGFloat.greatestFiniteMagnitude
        var closestKey: Key?
        for key in keys {
            let xDist = point.x - key.center.x
            let yDist = point.y - key.center.y
            let dist = sqrt(xDist * xDist + yDist * yDist)
            if dist < minDist {
                minDist = dist
                closestKey = key
            }
        }
        return closestKey
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let touch = touches.first!
        let touchPoint = touch.preciseLocation(in: self.keysView)
        self.highlightNearestKey(touchPoint: touchPoint)
        self.keyTouchDown(sender: self.activeKey, event: event)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.activeKey?.unHighlight()
        self.keyTouchUp(sender: self.activeKey, touches: touches, event: event)
        self.activeKey = nil
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        let touch = touches.first!
        let touchPoint = touch.preciseLocation(in: self.keysView)
        self.highlightNearestKey(touchPoint: touchPoint)
        self.keyTouchDown(sender: self.activeKey, event: event)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.activeKey?.unHighlight()
        self.activeKey = nil
    }
    
    @objc func keyTouchUp(sender: Key?, touches: Set<UITouch>, event: UIEvent?) {
        
        if sender == nil { return }
        
        switch sender!.type {
            
        case Key.KeyType.Letter:
            let action = sender!.name
            self.textDocumentProxy.insertText(action)
            self.touchPoints.append(touches.first!.preciseLocation(in: self.keysView))
            
        case Key.KeyType.Number:
            let action = sender!.name
            self.textDocumentProxy.insertText(action)
            
        case Key.KeyType.Punctuation:
            sender!.hidePopUp()
            let action = sender!.name
            self.textDocumentProxy.insertText(action)
            
        case Key.KeyType.SwitchToPrimaryMode,
             Key.KeyType.SwitchToSecondaryMode:
            self.switchKeyboardMode()
            
        case Key.KeyType.SwitchToUppercase,
             Key.KeyType.SwitchToLowercase:
            self.switchKeyboardCase()
            
        case Key.KeyType.SwitchToNumbers,
             Key.KeyType.SwitchToSymbols:
            self.switchKeyboardSpecial()
            
        case Key.KeyType.DismissKeyboard:
            self.dismissKeyboard()
            
        case Key.KeyType.Space:
            self.textDocumentProxy.insertText(" ")
            self.switchToPrimaryMode()
            self.touchPoints.removeAll()
        
            
        case Key.KeyType.Return:
            self.textDocumentProxy.insertText("\n")
            self.touchPoints.removeAll()
            
        case Key.KeyType.Backspace:
            self.stopBackspace()
            
        default:
            break
        }
    }
    
    @objc func keyTouchDown(sender: Key?, event: UIEvent?) {
        if sender == nil { return }
        switch sender!.type {
        case Key.KeyType.Backspace:
            self.startBackspace()
            self.touchPoints.removeAll()
        case Key.KeyType.KeyboardSelection:
            self.handleInputModeList(from: self.keyboardSelectionKey!, with: event!)
        default:
            break
        }
    }
}
