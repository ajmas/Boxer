/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXInputController.h"

/// The \c BXKeyboardInput category handles BXInputController's keyboard event responses
/// and simulated keyboard actions.
@interface BXInputController (BXKeyboardInput)

/// A mapping table of input source IDs to DOS keyboard layout codes.
/// Loaded from KeyboardLayouts.plist. 
+ (NSDictionary<NSString*,NSString*> *) keyboardLayoutMappings;

/// Returns the DOS keyboard layout code corresponding to the specified input source ID
+ (NSString *) keyboardLayoutForInputSourceID: (NSString *)inputSourceID;

/// Returns the DOS keyboard layout code corresponding to the current input source ID
+ (NSString *) keyboardLayoutForCurrentInputMethod;


#pragma mark -
#pragma mark Simulating keypresses

- (IBAction) sendF1:	(id)sender;
- (IBAction) sendF2:	(id)sender;
- (IBAction) sendF3:	(id)sender;
- (IBAction) sendF4:	(id)sender;
- (IBAction) sendF5:	(id)sender;
- (IBAction) sendF6:	(id)sender;
- (IBAction) sendF7:	(id)sender;
- (IBAction) sendF8:	(id)sender;
- (IBAction) sendF9:	(id)sender;
- (IBAction) sendF10:	(id)sender;
- (IBAction) sendF11:	(id)sender;
- (IBAction) sendF12:	(id)sender;

- (IBAction) sendHome:		(id)sender;
- (IBAction) sendEnd:		(id)sender;
- (IBAction) sendPageUp:	(id)sender;
- (IBAction) sendPageDown:	(id)sender;

- (IBAction) sendInsert:	(id)sender;
- (IBAction) sendDelete:	(id)sender;
- (IBAction) sendPause:		(id)sender;
- (IBAction) sendCtrlBreak: (id)sender;

- (IBAction) sendNumLock:		(id)sender;
- (IBAction) sendScrollLock:	(id)sender;
- (IBAction) sendPrintScreen:	(id)sender;

- (IBAction) sendBackslash:     (id)sender;
- (IBAction) sendForwardSlash:  (id)sender;
- (IBAction) sendColon:         (id)sender;
- (IBAction) sendDash:          (id)sender;

/// 'Types' the specified message into the DOS prompt by imitating keypress events.
- (void) type: (NSString *)message;

@end
