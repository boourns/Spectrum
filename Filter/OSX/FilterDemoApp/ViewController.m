/*
	Copyright (C) 2016 Apple Inc. All Rights Reserved.
	See LICENSE.txt for this sample’s licensing information
	
	Abstract:
	View controller which registers an AUAudioUnit subclass in-process for easy development, connects sliders and text fields to its parameters, and embeds the audio unit's view into a subview. Uses SimplePlayEngine to audition the effect.
*/

#import "ViewController.h"
#import "AppDelegate.h"

#import "FilterDemoFramework.h"
#import "FilterDemo-Swift.h"
#import <CoreAudioKit/AUViewController.h>
#import "FilterDemoViewController.h"

#define kMinHertz 12.0f
#define kMaxHertz 20000.0f

@interface ViewController () {
    IBOutlet NSButton *playButton;
    
    IBOutlet NSSlider *cutoffSlider;
    IBOutlet NSSlider *resonanceSlider;
    
    IBOutlet NSTextField *cutoffTextField;
    IBOutlet NSTextField *resonanceTextField;
    
    FilterDemoViewController *auV3ViewController;
    
    SimplePlayEngine *playEngine;
    
    AUParameter *cutoffParameter;
    AUParameter *resonanceParameter;
    
    AUParameterObserverToken parameterObserverToken;
    NSArray<AUAudioUnitPreset *> *factoryPresets;
}
@property (weak) IBOutlet NSView *containerView;

-(IBAction)togglePlay:(id)sender;
-(IBAction)changedCutoff:(id)sender;
-(IBAction)changedResonance:(id)sender;

-(void)handleMenuSelection:(id)sender;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Do any additional setup after loading the view.
    [self embedPlugInView];
    
    AudioComponentDescription desc;
    /*  Supply the correct AudioComponentDescription based on your AudioUnit type, manufacturer and creator.
     
        You need to supply matching settings in the AUAppExtension info.plist under:
         
        NSExtension
            NSExtensionAttributes
                AudioComponents
                    Item 0
                        type
                        subtype
                        manufacturer
         
         If you do not do this step, your AudioUnit will not work!!!
     */
    // MARK: AudioComponentDescription Important!
    // Ensure that you update the AudioComponentDescription for your AudioUnit type, manufacturer and creator type.
    desc.componentType = 'aufx';
    desc.componentSubType = 'f1tR';
    desc.componentManufacturer = 'Demo';
    desc.componentFlags = 0;
    desc.componentFlagsMask = 0;
    
    [AUAudioUnit registerSubclass: AUv3FilterDemo.class
           asComponentDescription: desc
                             name: @"Demo: Local AUv3"
                          version: UINT32_MAX];
    
    playEngine = [[SimplePlayEngine alloc] initWithComponentType: desc.componentType componentsFoundCallback: nil];
    [playEngine selectAudioUnitWithComponentDescription2:desc completionHandler:^{
        [self connectParametersToControls];
    }];

    [cutoffSlider sendActionOn:NSLeftMouseDraggedMask | NSLeftMouseDownMask];
    [resonanceSlider sendActionOn:NSLeftMouseDraggedMask | NSLeftMouseDownMask];
    
    [self populatePresetMenu];
}

#pragma mark -

- (void)embedPlugInView {
    NSURL *builtInPlugInURL = [[NSBundle mainBundle] builtInPlugInsURL];
    NSURL *pluginURL = [builtInPlugInURL URLByAppendingPathComponent: @"FilterDemoAppExtension.appex"];
    NSBundle *appExtensionBundle = [NSBundle bundleWithURL: pluginURL];
    
    auV3ViewController = [[FilterDemoViewController alloc] initWithNibName: @"FilterDemoViewController"
                                                                    bundle: appExtensionBundle];
    
    NSView *view = auV3ViewController.view;
    view.frame = _containerView.bounds;
    
    [_containerView addSubview: view];
    
    view.translatesAutoresizingMaskIntoConstraints = NO;
    
    NSArray *constraints = [NSLayoutConstraint constraintsWithVisualFormat: @"H:|-[view]-|"
                                                                   options:0 metrics:nil
                                                                     views:NSDictionaryOfVariableBindings(view)];
    [_containerView addConstraints: constraints];
    
    constraints = [NSLayoutConstraint constraintsWithVisualFormat: @"V:|-[view]-|"
                                                          options:0 metrics:nil
                                                            views:NSDictionaryOfVariableBindings(view)];
    [_containerView addConstraints: constraints];
}

-(void) connectParametersToControls {
    AUParameterTree *parameterTree = playEngine.testAudioUnit.parameterTree;
    
    auV3ViewController.audioUnit = (AUv3FilterDemo *)playEngine.testAudioUnit;
    cutoffParameter = [parameterTree valueForKey: @"cutoff"];
    resonanceParameter = [parameterTree valueForKey: @"resonance"];
    
    __weak ViewController *weakSelf = self;
    parameterObserverToken = [parameterTree tokenByAddingParameterObserver:^(AUParameterAddress address, AUValue value) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong ViewController *strongSelf = weakSelf;
            
            if (address == cutoffParameter.address)
                [strongSelf updateCutoff];
            else if (address == resonanceParameter.address)
                [strongSelf updateResonance];
        });
    }];
    
    [self updateCutoff];
    [self updateResonance];
}

#pragma mark-
#pragma mark: <NSWindowDelegate>

- (void)windowWillClose:(NSNotification *)notification {
    // Main applicaiton window closing, we're done
    [playEngine stopPlaying];
    [playEngine.testAudioUnit.parameterTree removeParameterObserver:parameterObserverToken];
    
    playEngine = nil;
    auV3ViewController = nil;
}

#pragma mark-

static double logValueForNumber(double number) {
    return log(number)/log(2);
}

static double frequencyValueForSliderLocation(double location) {
    double value = powf(2, location); // (this gives us 2^0->2^9)
    value = (value - 1) / 511;        // (normalize based on rage of 2^9-1)

    // map to frequency range
    value *= (kMaxHertz - kMinHertz);
    
    return value + kMinHertz;
}

-(void) updateCutoff {
    cutoffTextField.stringValue = [cutoffParameter stringFromValue:nil];
    
    double cutoffValue = cutoffParameter.value;
    
    // normalize the value from 0-1
    double normalizedValue = ((cutoffValue - kMinHertz) / (kMaxHertz - kMinHertz));
    
    // map to 2^0 - 2^9 (slider range)
    normalizedValue = (normalizedValue * 511.0) + 1;
    
    double location = logValueForNumber(normalizedValue);
    cutoffSlider.doubleValue = location;
}

-(void) updateResonance {
    resonanceTextField.stringValue = [resonanceParameter stringFromValue: nil];
    resonanceSlider.doubleValue = resonanceParameter.value;
    
	[resonanceTextField setNeedsDisplay: YES];
    [resonanceSlider setNeedsDisplay: YES];
}

#pragma mark-
#pragma mark: Actions

-(IBAction)togglePlay:(id)sender {
    BOOL isPlaying = [playEngine togglePlay];
    
    [playButton setTitle: isPlaying ? @"Stop" : @"Play"];
}

-(IBAction)changedCutoff:(id)sender {
    if (sender == cutoffTextField)
        cutoffParameter.value = ((NSControl *)sender).doubleValue;
    else if (sender == cutoffSlider) {
        // map to frequency value
        double value = frequencyValueForSliderLocation(((NSControl *)sender).doubleValue);
        cutoffParameter.value = value;
    }
}

-(IBAction)changedResonance:(id)sender {
    if (sender == resonanceSlider || sender == resonanceTextField)
        resonanceParameter.value = ((NSControl *)sender).doubleValue;
}

#pragma mark-
#pragma mark Application Preset Menu

-(void)populatePresetMenu {
    NSApplication *app = [NSApplication sharedApplication];
    NSMenu *presetMenu = [[app.mainMenu itemWithTag:666] submenu];
    
    factoryPresets = auV3ViewController.audioUnit.factoryPresets;
    
    for (AUAudioUnitPreset *thePreset in factoryPresets) {
        NSString *keyEquivalent = @"";
        
        if (thePreset.number <= 10) {
            long keyValue = ((thePreset.number < 10) ? (long)(thePreset.number + 1) : 0);
            keyEquivalent =[NSString stringWithFormat: @"%ld", keyValue];
        }
        
        NSMenuItem *newItem = [[NSMenuItem alloc] initWithTitle:thePreset.name
                                                         action:@selector(handleMenuSelection:)
                                                  keyEquivalent:keyEquivalent];
        newItem.tag = thePreset.number;
        [presetMenu addItem:newItem];
    }
    
    AUAudioUnitPreset *currentPreset = auV3ViewController.audioUnit.currentPreset;
    [presetMenu itemAtIndex: currentPreset.number].state = NSOnState;
}

-(void)handleMenuSelection:(NSMenuItem *)sender {
    
    for (NSMenuItem *menuItem in [sender.menu itemArray]) {
        menuItem.state = NSOffState;
    }
    
    sender.state = NSOnState;
    auV3ViewController.audioUnit.currentPreset = [factoryPresets objectAtIndex:sender.tag];
}

@end
