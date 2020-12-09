/*
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXDrive.h"

//These properties should only be used by categories and subclasses of BXDrive.

@interface BXDrive ()

@property (readwrite, nonatomic) BXDriveType type;
@property (readwrite, strong, nonatomic) id <ADBFilesystemPathAccess, ADBFilesystemLogicalURLAccess> filesystem;

@property (nonatomic) BOOL hasAutodetectedMountPoint;
@property (nonatomic) BOOL hasAutodetectedLetter;
@property (nonatomic) BOOL hasAutodetectedType;
@property (nonatomic) BOOL hasAutodetectedTitle;
@property (nonatomic) BOOL hasAutodetectedVolumeLabel;

@end
