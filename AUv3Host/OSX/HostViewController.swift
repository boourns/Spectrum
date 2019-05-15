/*
	Copyright (C) 2016 Apple Inc. All Rights Reserved.
	See LICENSE.txt for this sample’s licensing information
	
	Abstract:
	View controller managing selection of an audio unit and presets, opening/closing an audio unit's view, and starting/stopping audio playback.
*/

import Cocoa
import AVFoundation
import CoreAudioKit

class HostViewController: NSViewController {
    @IBOutlet weak var instrumentEffectsSelector: NSSegmentedControl!
    @IBOutlet weak var playButton: NSButton!
    @IBOutlet weak var effectTable: NSTableView!
    
    @IBOutlet weak var showCustomViewButton: NSButton!

    @IBOutlet weak var auViewContainer: NSView!

    @IBOutlet weak var verticalLine: NSBox!
    
    @IBOutlet weak var horizontalViewSizeConstraint: NSLayoutConstraint!
    @IBOutlet weak var verticalViewSizeConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var verticalLineLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var verticalLineTrailingConstraint: NSLayoutConstraint!

    
    let kAUViewSizeDefaultWidth: CGFloat = 484.0
    let kAUViewSizeDefaultHeight:CGFloat = 400.0
    
    var isDisplayingCustomView: Bool = false
    
    var auView: NSView?
    var playEngine: SimplePlayEngine!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        horizontalViewSizeConstraint.constant = 0;
        verticalLineLeadingConstraint.constant = 0;
        verticalLineTrailingConstraint.constant = 0;
        
        showCustomViewButton.isEnabled = false

        playEngine = SimplePlayEngine(componentType: kAudioUnitType_Effect) {
            self.effectTable.reloadData()
        }
    }

    func numberOfRowsInTableView(_ aTableView: NSTableView) -> Int {
        if aTableView === effectTable {
            return playEngine.availableAudioUnits.count + 1
        }
        return 0
    }
    
    @IBAction func togglePlay(_ sender: AnyObject?) {
        let isPlaying = playEngine.togglePlay()
        
        playButton.title = isPlaying ? "Stop" : "Play"
    }
    
    @IBAction func selectInstrumentOrEffect(_ sender: AnyObject?) {
        let isInstrument = instrumentEffectsSelector.selectedSegment == 0 ? false : true
        if (isInstrument) {
            playEngine.setInstrument()
        } else {
            playEngine.setEffect()
        }
        
        playButton.title = "Play"
        effectTable.reloadData()
        
        if (self.effectTable.selectedRow <= 0) {
            self.showCustomViewButton.isEnabled = false
        } else {
            self.showCustomViewButton.isEnabled = true
        }
        
        closeAUView()
    }
    
    func closeAUView() {
        if (!isDisplayingCustomView) {
            return;
        }
        
        isDisplayingCustomView = false
        
        auView?.removeFromSuperview()
        auView = nil
        
        horizontalViewSizeConstraint.constant = 0
        verticalLineLeadingConstraint.constant = 0;
        verticalLineTrailingConstraint.constant = 0;
        
        verticalLine.isHidden = true
        
        showCustomViewButton.title = "Show Custom View"
    }
    
    @IBAction func openViewAction(_ sender: AnyObject?) {
        if (isDisplayingCustomView) {
            if (auView != nil) {
                closeAUView()
                return
            }
        } else {
            /*
             Request the view controller asynchronously from the audio unit. This
             only happens if the audio unit is non-nil.
             */
            playEngine.testAudioUnit?.requestViewController { [weak self] viewController in
                guard let strongSelf = self else {return}
                
                guard let viewController = viewController else {return}
                
                strongSelf.showCustomViewButton.title = "Hide Custom View"
                
                strongSelf.verticalLine.isHidden = false
                strongSelf.verticalLineLeadingConstraint.constant = 8
                strongSelf.verticalLineTrailingConstraint.constant = 8
                
                let view = viewController.view
                view.translatesAutoresizingMaskIntoConstraints = false
                view.postsFrameChangedNotifications = true
                
                var viewSize: NSSize = view.frame.size
                
                viewSize.width = max(view.frame.width, self!.kAUViewSizeDefaultWidth)
                viewSize.height = max(view.frame.height, self!.kAUViewSizeDefaultHeight)
                
                strongSelf.horizontalViewSizeConstraint.constant = viewSize.width;
                strongSelf.verticalViewSizeConstraint.constant = viewSize.height;
                
                let superview = strongSelf.auViewContainer
                
                superview?.addSubview(view)
                
                let preferredSize = viewController.preferredContentSize
                
                let views = ["view": view]; //, "superview": superview];
                let horizontalConstraints = NSLayoutConstraint.constraints(withVisualFormat: "H:|[view]|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: views)
                superview?.addConstraints(horizontalConstraints)
                
                // If a view has no preferred size, or a large preferred size, add a leading and trailing constraint. Otherwise, just a trailing constraint
                if (preferredSize.height == 0 || preferredSize.height > strongSelf.kAUViewSizeDefaultHeight) {
                    let verticalConstraints = NSLayoutConstraint.constraints(withVisualFormat: "V:|[view]|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: views)
                    superview?.addConstraints(verticalConstraints)
                } else {
                    let verticalConstraints = NSLayoutConstraint.constraints(withVisualFormat: "V:|[view]", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: views)
                    superview?.addConstraints(verticalConstraints)
                }
                
                NotificationCenter.default.addObserver(strongSelf, selector: #selector(HostViewController.auViewSizeChanged(_:)), name:
                    NSNotification.Name.NSViewFrameDidChange, object: nil)
                
                strongSelf.auView = view
                strongSelf.auView?.needsDisplay = true
                strongSelf.auViewContainer.needsDisplay = true
                
                strongSelf.isDisplayingCustomView = true
            }
        }
    }
    
    func auViewSizeChanged(_ notification : NSNotification) {
        if (notification.object! as! NSView === auView ) {
            self.horizontalViewSizeConstraint.constant = (notification.object! as AnyObject).frame.size.width
            
            if ((notification.object! as AnyObject).frame.size.height > self.kAUViewSizeDefaultHeight) {
                self.verticalViewSizeConstraint.constant = (notification.object! as AnyObject).frame.size.height
            }
        }
    }

    func tableView(_ tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if tableView === effectTable {
            let result = tableView.make(withIdentifier: "MyView", owner: self) as! NSTableCellView
            
            if row > 0 && row <= playEngine.availableAudioUnits.count {
                let component = playEngine.availableAudioUnits[row - 1];
                result.textField!.stringValue = "\(component.name) (\(component.manufacturerName))"
            } else {
                if playEngine.isEffect() {
                    result.textField!.stringValue = "(No effect)"
                } else {
                    result.textField!.stringValue = "(No instrument)"
                }
            }
            
            return result
        }
        return nil
    }
    
    func tableViewSelectionDidChange(_ aNotification: NSNotification) {
        let tableView: NSTableView = aNotification.object as! NSTableView
        
        if tableView === effectTable {
            self.closeAUView()
            let row = tableView.selectedRow
            let component: AVAudioUnitComponent?
            
            if row > 0 {
                component = playEngine.availableAudioUnits[row-1]
                showCustomViewButton.isEnabled = true
            } else {
                component = nil
                showCustomViewButton.isEnabled = false
            }
            
            playEngine.selectAudioUnitComponent(component, completionHandler: {})
        }
    }
}
