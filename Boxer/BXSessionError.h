/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXImportError defines custom import-related errors.

#import <Foundation/Foundation.h>
#import "NSError+ADBErrorHelpers.h"

NS_ASSUME_NONNULL_BEGIN

//Error domains and codes
extern NSErrorDomain const BXSessionErrorDomain;
typedef NS_ERROR_ENUM(BXSessionErrorDomain, BXSessionErrorValue)
{
    BXSessionCannotMountSystemFolder,   //!< Returned when user attempts to mount an OS X system folder as a DOS drive.
	
    BXImportNoExecutablesInSource,      //!< Returned when the import scanner can find no executables of any kind in the source folder.
	BXImportSourceIsWindowsOnly,        //!< Returned when the import scanner can only find Windows executables in the source folder.
	BXImportSourceIsMacOSApp,           //!< Returned when the import scanner can only find Mac applications in the source folder.
	BXImportSourceIsHybridCD,           //!< Returned when the import scanner detects a hybrid Mac+PC CD.
    BXImportDriveUnavailable,           //!< Returned when a DOSBox configuration file was provided that defines drives with paths that cannot be found.
    
    BXGameStateUnsupported,     //!< Returned when the current session does not support game states. (e.g. no gamebox is present.)
    BXGameStateGameboxMismatch, //!< Returned when validating a boxerstate file, if it is for a different game than the current game.
    
    BXSessionNotReady,          //!< Returned when \c openURLInDOS:error: is not ready to open a program.
    BXURLNotReachableInDOS,     //!< Returned when \c openURLInDOS:error: is passed a URL that cannot be mapped to a DOS path.
};

//! General base class for all session errors
@interface BXSessionError : NSError
@end

//! Errors specific to game importing
@interface BXImportError : BXSessionError
@end

@interface BXSessionCannotMountSystemFolderError : BXSessionError
+ (instancetype) errorWithFolderURL: (NSURL *)folderURL userInfo: (nullable NSDictionary<NSErrorUserInfoKey, id> *)userInfo;
@end

@interface BXImportNoExecutablesError : BXImportError
+ (instancetype) errorWithSourceURL: (NSURL *)sourceURL userInfo: (nullable NSDictionary<NSErrorUserInfoKey, id> *)userInfo;
@end

@interface BXImportWindowsOnlyError : BXImportError
+ (instancetype) errorWithSourceURL: (NSURL *)sourceURL userInfo: (nullable NSDictionary<NSErrorUserInfoKey, id> *)userInfo;
- (NSString *) helpAnchor;
@end

@interface BXImportHybridCDError : BXImportError
+ (instancetype) errorWithSourceURL: (NSURL *)sourceURL userInfo: (nullable NSDictionary<NSErrorUserInfoKey, id> *)userInfo;
@end

@interface BXImportMacAppError : BXImportError
+ (instancetype) errorWithSourceURL: (NSURL *)sourceURL userInfo: (nullable NSDictionary<NSErrorUserInfoKey, id> *)userInfo;
@end

@class BXDrive;
@interface BXImportDriveUnavailableError : BXImportError
+ (instancetype) errorWithSourceURL: (NSURL *)sourceURL drive: (BXDrive *)drive userInfo: (nullable NSDictionary<NSErrorUserInfoKey, id> *)userInfo;
@end

@class BXGamebox;
@interface BXGameStateGameboxMismatchError : BXSessionError
+ (instancetype) errorWithStateURL: (NSURL *)stateURL gamebox: (BXGamebox *)gamebox userInfo: (nullable NSDictionary<NSErrorUserInfoKey, id> *)userInfo;
@end

@interface BXSessionNotReadyError : BXSessionError

+ (instancetype) errorWithUserInfo: (nullable NSDictionary<NSErrorUserInfoKey, id> *)userInfo;

@end

@interface BXSessionURLNotReachableError : BXSessionError
+ (instancetype) errorWithURL: (NSURL *)URL userInfo: (nullable NSDictionary<NSErrorUserInfoKey, id> *)userInfo;
@end

NS_ASSUME_NONNULL_END
