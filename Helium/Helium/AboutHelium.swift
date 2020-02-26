//
//  AboutHelium.swift
//  Helium
//
//  Created by Carlos D. Santiago on 6/24/17.
//  Copyright © 2017-2020 Carlos D. Santiago. All rights reserved.
//

import Foundation
let kTitleUtility =		16
let	kTitleNormal =		22

class AboutBoxController : NSViewController {
	
    @objc @IBOutlet var toggleButton: NSButton!
	@objc @IBOutlet var appNameField: NSTextField!
    @objc @IBOutlet var creditScroll: NSScrollView!
	@objc @IBOutlet var creditsField: NSTextView!
    @objc @IBOutlet var creditsButton: NSButton!
    @objc @IBOutlet var versionButton: NSButton!
    @objc @IBOutlet var creditSeparatorBox: NSBox!
    
    @objc @IBOutlet var hideView: NSView!
    var hideRect: NSRect?
    var origRect: NSRect?
    
	@objc @IBOutlet var appNameButton: NSButton!
	@objc @IBAction func appButtonPress(_ sender: Any) {
        var info = Dictionary<String,Any>()
        info[k.name] = appName
        info[k.vers] = versionString!
        info[k.data] = versionData!
        info[k.link] = versionLink!
        info[k.date] = versionDate!
        
        let json = try? JSONSerialization.data(withJSONObject: info, options: [])
        let jsonString = String(data: json!, encoding: .utf8)
        
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([NSPasteboard.PasteboardType.string], owner: nil)
        if pasteboard.setString(jsonString!, forType: NSPasteboard.PasteboardType.string) {
            Swift.print("app info copied to pasteboard")
        }
	}
	
    @objc @IBAction func toggleContent(_ sender: Any) {
        // Toggle content visibility
        if let window = self.view.window {
            let oldSize = window.contentView?.bounds.size
            var frame = window.frame
            if toggleButton.state == .off {
                
                frame.origin.y += ((oldSize?.height)! - (hideRect?.size.height)!)
                window.setFrameOrigin(frame.origin)
                window.setContentSize((hideRect?.size)!)
                
                window.showsResizeIndicator = false
                window.minSize = NSMakeSize((hideRect?.size.width)!,(hideRect?.size.height)!+CGFloat(kTitleNormal))
                window.maxSize = window.minSize
                creditScroll.isHidden = true
                showCredits()
            }
            else
            {
                let hugeSize = NSMakeSize(CGFloat(Float.greatestFiniteMagnitude), CGFloat(Float.greatestFiniteMagnitude))
                
                frame.origin.y += ((oldSize?.height)! - (origRect?.size.height)!)
                window.setFrameOrigin(frame.origin)
                window.setContentSize((origRect?.size)!)

                window.showsResizeIndicator = true
                window.minSize = NSMakeSize((origRect?.size.width)!,(origRect?.size.height)!+CGFloat(kTitleNormal))
                window.maxSize = hugeSize
                creditScroll.isHidden = false
            }
        }
    }
    
    internal func showCredits() {
        let credits = ["README", "History", "LICENSE"];
        
        if AboutBoxController.creditsState >= AboutBoxController.maxStates
        {
            AboutBoxController.creditsState = 0
        }
        //	Setup our credits; if sender is nil, give 'em long history
        let creditsString = NSAttributedString.string(fromAsset: credits[AboutBoxController.creditsState])
        creditsField.string = creditsString
    }
    
    @objc @IBAction func cycleCredits(_ sender: Any) {

        AboutBoxController.creditsState += 1

        if toggleButton.state == .off {
            if AboutBoxController.creditsState >= AboutBoxController.creditsCount
            {
                AboutBoxController.creditsState = 0
            }
            creditsButton.title = copyrightStrings![AboutBoxController.creditsState % AboutBoxController.creditsCount]
        }
        else
        {
            showCredits()
        }
    }
    
    @objc @IBAction func toggleVersion(_ sender: Any) {
        
        AboutBoxController.versionState += 1
        if AboutBoxController.versionState >= AboutBoxController.maxStates
        {
            AboutBoxController.versionState = 0
        }

        let titles = [ versionData, versionLink, versionDate ]
        versionButton.title = titles[AboutBoxController.versionState]!

        let tooltip = [ "version", "build", "timestamp" ]
        versionButton.toolTip = tooltip[AboutBoxController.versionState];
    }

    var versionData: String? = nil
    var versionLink: String? = nil
    var versionDate: String? = nil

    var appName: String {
        get {
            return (NSApp.delegate as! AppDelegate).appName
        }
    }
    var versionString: String? = nil
    var copyrightStrings: [String]? = nil

    static var versionState: Int = 0
    static var creditsState: Int = 0
    static let maxStates: Int = 3
    static let creditsCount: Int = 2// CDS, JG, ...

    override func viewWillAppear() {
        let theWindow = appNameField.window

        //	We no need no sticking title!
        theWindow?.title = ""

        appNameField.stringValue = appName
        versionButton.title = versionData!
        creditsButton.title = copyrightStrings![AboutBoxController.creditsState % AboutBoxController.creditsCount]

        if (appNameField.window?.isVisible)! {
            creditsField.scroll(NSMakePoint( 0, 0 ))
        }
        
        // Version criteria to cycle thru
        AboutBoxController.versionState = -1
        toggleVersion(self)

        //  Credit criteria initially hidden
        AboutBoxController.creditsState = 0-1
        toggleButton.state = .off
        cycleCredits(self)
        toggleContent(self)
        
        // Setup the window
        theWindow?.isExcludedFromWindowsMenu = true
        theWindow?.menu = nil
        theWindow?.center()

        //	Show the window
        appNameField.window?.makeKeyAndOrderFront(self)
    }
    
    override func viewDidLoad() {
        //	Initially don't show history
        toggleButton.state = .off
 
        //	Get the info dictionary (Info.plist)
        let infoDictionary = (Bundle.main.infoDictionary)!

        //	Setup the version to one we constrict
        versionString = String(format:"Version %@",
                               infoDictionary["CFBundleShortVersionString"] as! CVarArg)

        // Version criteria to cycle thru
        self.versionData = versionString;
        self.versionLink = String(format:"Build %@",
                                  infoDictionary["CFBuildNumber"] as! CVarArg)
        self.versionDate = infoDictionary["CFBuildDate"] as? String;

        //  Capture hide and show initial sizes
        hideRect = hideView.frame
        origRect = self.view.frame

        // Setup the copyrights field; each separated by "|"
        copyrightStrings = (infoDictionary["NSHumanReadableCopyright"] as? String)?.components(separatedBy: "|")
        toggleButton.state = .off
    }
    
}
