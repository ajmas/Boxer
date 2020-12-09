/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import <Cocoa/Cocoa.h>

@class BXSession;
@class BXDrive;

/// \c BXDrivesInUseAlert is shown when a user tries to unmount one or more drives that are currently
/// being accessed by the DOS process. It displays a warning and confirmation.
@interface BXDrivesInUseAlert : NSAlert

/// Initialise and return a new alert, whose text refers to the drives and session provided.
- (instancetype) initWithDrives: (NSArray<BXDrive*> *)drivesInUse forSession: (BXSession *)theSession;

@end
