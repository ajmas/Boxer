/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXSessionError.h"
#import "BXDrive.h"
#import "BXGamebox.h"
#import "BXValueTransformers.h"
#import "NSURL+ADBFilesystemHelpers.h"

NSString * const BXSessionErrorDomain = @"BXSessionErrorDomain";

@implementation BXSessionError
+ (void)load
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		[NSError setUserInfoValueProviderForDomain:BXSessionErrorDomain provider:^id _Nullable(NSError * _Nonnull err, NSErrorUserInfoKey  _Nonnull userInfoKey) {
			switch (err.code) {
				case BXSessionCannotMountSystemFolder:
					if ([userInfoKey isEqualToString:NSLocalizedDescriptionKey]) {
						NSString *descriptionFormat = NSLocalizedString(@"MS-DOS is not permitted to access OS X system folders like “%@”.",
																		@"Error message shown when user tries to mount a system folder as a DOS drive. %@ is the requested folder path."
																		);
						NSURL *folderURL = err.userInfo[NSURLErrorKey];
						NSString *description = [NSString stringWithFormat: descriptionFormat, folderURL.localizedName];
						return description;
					} else if ([userInfoKey isEqualToString:NSLocalizedRecoverySuggestionErrorKey]) {
						return NSLocalizedString(@"Instead, choose one of your own folders, or a disc mounted in OS X.", @"Recovery suggestion shown when user tries to mount a system folder as a DOS drive.");
					}
					break;

				case BXImportNoExecutablesInSource:
					if ([userInfoKey isEqualToString:NSLocalizedDescriptionKey]) {
						NSString *descriptionFormat = NSLocalizedString(@"“%@” does not contain any MS-DOS programs.",
																		@"Error message shown when importing a folder with no executables in it. %@ is the display filename of the imported folder.");
						NSURL *folderURL = err.userInfo[NSURLErrorKey];
						NSString *description = [NSString stringWithFormat: descriptionFormat, folderURL.localizedName];
						return description;
					} else if ([userInfoKey isEqualToString:NSLocalizedRecoverySuggestionErrorKey]) {
						return NSLocalizedString(@"This folder may contain a game for another platform which is not supported by Boxer.",
												 @"Explanation text shown when importing a folder with no executables in it.");
					}
					break;

				case BXImportSourceIsWindowsOnly:
					if ([userInfoKey isEqualToString:NSLocalizedDescriptionKey]) {
						NSString *descriptionFormat = NSLocalizedString(@"“%@” is a Windows game. Boxer only supports MS-DOS games.",
																		@"Error message shown when importing a folder that contains a Windows-only game or Windows installer. %@ is the display filename of the imported path.");
						NSURL *folderURL = err.userInfo[NSURLErrorKey];
						NSString *description = [NSString stringWithFormat: descriptionFormat, folderURL.localizedName];
						return description;
					} else if ([userInfoKey isEqualToString:NSLocalizedRecoverySuggestionErrorKey]) {
						return NSLocalizedString(@"You can run this game in a Windows emulator instead. For more help, click the ? button.",
												 @"Informative text of warning sheet after importing a Windows-only game.");
					} else if ([userInfoKey isEqualToString:NSHelpAnchorErrorKey]) {
						return @"windows-games";
					}
					break;

				case BXImportSourceIsMacOSApp:
					if ([userInfoKey isEqualToString:NSLocalizedDescriptionKey]) {
						NSString *descriptionFormat = NSLocalizedString(@"“%@” is a Mac OS game. Boxer only supports MS-DOS games.",
																		@"Error message shown when importing a folder that contains a Mac game. %@ is the display filename of the imported path.");
						NSURL *folderURL = err.userInfo[NSURLErrorKey];
						NSString *description = [NSString stringWithFormat: descriptionFormat, folderURL.localizedName];
						return description;
					} else if ([userInfoKey isEqualToString:NSLocalizedRecoverySuggestionErrorKey]) {
						return NSLocalizedString(@"If you cannot play this game in OS X, you may be able to play it in a Classic Mac OS emulator instead. For more help, click the ? button.",
												 @"Informative text of warning sheet after importing a Mac application.");
					} else if ([userInfoKey isEqualToString:NSHelpAnchorErrorKey]) {
						return @"macos-games";
					}
					break;
					
				case BXImportSourceIsHybridCD:
					if ([userInfoKey isEqualToString:NSLocalizedDescriptionKey]) {
						NSString *descriptionFormat = NSLocalizedString(@"“%@” is a Mac+PC hybrid disc, which Boxer cannot import.",
																		@"Error message shown when importing a hybrid Mac/PC CD. %@ is the display filename of the imported path.");
						NSURL *folderURL = err.userInfo[NSURLErrorKey];
						NSString *description = [NSString stringWithFormat: descriptionFormat, folderURL.localizedName];
						return description;
					} else if ([userInfoKey isEqualToString:NSLocalizedRecoverySuggestionErrorKey]) {
						return NSLocalizedString(@"You can insert the disc into a Windows PC instead, and copy the DOS version of the game from there to your Mac. For more help, click the ? button.",
												 @"Informative text of warning sheet when importing a hybrid Mac/PC CD.");
					} else if ([userInfoKey isEqualToString:NSHelpAnchorErrorKey]) {
						return @"hybrid-cds";
					}
					break;
					
				case BXImportDriveUnavailable:
					if ([userInfoKey isEqualToString:NSLocalizedDescriptionKey]) {
						NSString *descriptionFormat = NSLocalizedString(@"“%1$@” requires extra files that are currently unavailable.",
																		@"Error message shown when importing a folder that has missing drives. %1$@ is the display filename of the imported path.");
						NSURL *folderURL = err.userInfo[NSURLErrorKey];
						NSString *description = [NSString stringWithFormat: descriptionFormat, folderURL.localizedName];
						return description;
					} else if ([userInfoKey isEqualToString:NSLocalizedFailureReasonErrorKey]) {
						return NSLocalizedString(@"A DOSBox configuration file was provided that defines drives with paths that cannot be found.", @"A DOSBox configuration file was provided that defines drives with paths that cannot be found.");
					}

					break;
					
				case BXGameStateUnsupported:
					if ([userInfoKey isEqualToString:NSLocalizedDescriptionKey]) {
						return NSLocalizedString(@"Unsupported state", @"Unsupported state");
					} else if ([userInfoKey isEqualToString:NSLocalizedFailureReasonErrorKey]) {
						return NSLocalizedString(@"The current session does not support game states. (e.g. no gamebox is present.)", @"Explanatory message when an unsupported state was requested.");
					}
					break;
					
				case BXSessionNotReady:
					if ([userInfoKey isEqualToString:NSLocalizedDescriptionKey]) {
						return NSLocalizedString(@"Session is not ready", @"Session is not ready");
					} else if ([userInfoKey isEqualToString:NSLocalizedFailureReasonErrorKey]) {
						return @"Returned when openURLInDOS:error: is not ready to open a program.";
					}
					break;
					
				case BXURLNotReachableInDOS:
					if ([userInfoKey isEqualToString:NSLocalizedDescriptionKey]) {
						return NSLocalizedString(@"URL not reachable in DOS", @"Localized description for when a requested URL cannot be opened from within DOS.");
					} else if ([userInfoKey isEqualToString:NSLocalizedFailureReasonErrorKey]) {
						return @"Returned when openURLInDOS:error: is passed a URL that cannot be mapped to a DOS path.";
					}
					break;

				default:
					return nil;
					break;
			}
			return nil;
		}];
	});
}
@end

@implementation BXImportError
@end


@implementation BXSessionCannotMountSystemFolderError

+ (id) errorWithFolderURL: (NSURL *)folderURL userInfo: (NSDictionary *)userInfo
{
    NSString *descriptionFormat = NSLocalizedString(@"MS-DOS is not permitted to access OS X system folders like “%@”.",
                                                    @"Error message shown when user tries to mount a system folder as a DOS drive. %@ is the requested folder path."
                                                    );
    
    NSString *suggestion = NSLocalizedString(@"Instead, choose one of your own folders, or a disc mounted in OS X.", @"Recovery suggestion shown when user tries to mount a system folder as a DOS drive.");
    
    NSString *description = [NSString stringWithFormat: descriptionFormat, folderURL.localizedName];
    NSMutableDictionary *defaultInfo = [NSMutableDictionary dictionaryWithDictionary: @{
                                                           NSLocalizedDescriptionKey: description,
                                               NSLocalizedRecoverySuggestionErrorKey: suggestion,
                                                                       NSURLErrorKey: folderURL,
                                         }];
    
	if (userInfo)
        [defaultInfo addEntriesFromDictionary: userInfo];
    
	return [self errorWithDomain: BXSessionErrorDomain
							code: BXSessionCannotMountSystemFolder
						userInfo: defaultInfo];
}
@end


@implementation BXImportNoExecutablesError

+ (id) errorWithSourceURL: (NSURL *)sourceURL userInfo: (NSDictionary *)userInfo
{
	NSString *descriptionFormat = NSLocalizedString(@"“%@” does not contain any MS-DOS programs.",
													@"Error message shown when importing a folder with no executables in it. %@ is the display filename of the imported folder.");
	
	NSString *suggestion = NSLocalizedString(@"This folder may contain a game for another platform which is not supported by Boxer.",
											 @"Explanation text shown when importing a folder with no executables in it.");
	
	NSString *description = [NSString stringWithFormat: descriptionFormat, sourceURL.localizedName];
	
	
	NSMutableDictionary *defaultInfo = [NSMutableDictionary dictionaryWithDictionary: @{
                                                           NSLocalizedDescriptionKey: description,
                                               NSLocalizedRecoverySuggestionErrorKey: suggestion,
                                                                       NSURLErrorKey: sourceURL,
                                        }];
	
	if (userInfo)
        [defaultInfo addEntriesFromDictionary: userInfo];
	
	return [self errorWithDomain: BXSessionErrorDomain
							code: BXImportNoExecutablesInSource
						userInfo: defaultInfo];
}

@end


@implementation BXImportWindowsOnlyError

+ (id) errorWithSourceURL: (NSURL *)sourceURL userInfo: (NSDictionary *)userInfo
{
	NSString *descriptionFormat = NSLocalizedString(
		@"“%@” is a Windows game. Boxer only supports MS-DOS games.",
		@"Error message shown when importing a folder that contains a Windows-only game or Windows installer. %@ is the display filename of the imported path."
	);
	
	NSString *suggestion = NSLocalizedString(
		@"You can run this game in a Windows emulator instead. For more help, click the ? button.",
		@"Informative text of warning sheet after importing a Windows-only game."
	);
	
	NSString *description = [NSString stringWithFormat: descriptionFormat, sourceURL.localizedName];
	
	NSMutableDictionary *defaultInfo = [NSMutableDictionary dictionaryWithDictionary: @{
                                                           NSLocalizedDescriptionKey: description,
                                               NSLocalizedRecoverySuggestionErrorKey: suggestion,
                                                                       NSURLErrorKey: sourceURL,
                                        }];
	
	if (userInfo) [defaultInfo addEntriesFromDictionary: userInfo];
	
	return [self errorWithDomain: BXSessionErrorDomain
							code: BXImportSourceIsWindowsOnly
						userInfo: defaultInfo];
}

- (NSString *) helpAnchor
{
	return @"windows-games";
}
@end


@implementation BXImportHybridCDError

+ (id) errorWithSourceURL: (NSURL *)sourceURL userInfo: (NSDictionary *)userInfo
{
	NSString *descriptionFormat = NSLocalizedString(@"“%@” is a Mac+PC hybrid disc, which Boxer cannot import.",
                                                    @"Error message shown when importing a hybrid Mac/PC CD. %@ is the display filename of the imported path.");
	
	NSString *suggestion = NSLocalizedString(@"You can insert the disc into a Windows PC instead, and copy the DOS version of the game from there to your Mac. For more help, click the ? button.",
                                             @"Informative text of warning sheet when importing a hybrid Mac/PC CD.");
	
	NSString *description = [NSString stringWithFormat: descriptionFormat, sourceURL.localizedName];
	
	NSMutableDictionary *defaultInfo = [NSMutableDictionary dictionaryWithDictionary: @{
                                                           NSLocalizedDescriptionKey: description,
                                               NSLocalizedRecoverySuggestionErrorKey: suggestion,
                                                                       NSURLErrorKey: sourceURL,
                                        }];
	
	if (userInfo)
        [defaultInfo addEntriesFromDictionary: userInfo];
	
	return [self errorWithDomain: BXSessionErrorDomain
							code: BXImportSourceIsHybridCD
						userInfo: defaultInfo];
}

- (NSString *) helpAnchor
{
	return @"hybrid-cds";
}
@end

@implementation BXImportMacAppError

+ (id) errorWithSourceURL: (NSURL *)sourceURL userInfo: (NSDictionary *)userInfo
{
	NSString *descriptionFormat = NSLocalizedString(@"“%@” is a Mac OS game. Boxer only supports MS-DOS games.",
                                                    @"Error message shown when importing a folder that contains a Mac game. %@ is the display filename of the imported path.");
	
	NSString *suggestion = NSLocalizedString(@"If you cannot play this game in OS X, you may be able to play it in a Classic Mac OS emulator instead. For more help, click the ? button.",
                                             @"Informative text of warning sheet after importing a Mac application.");
	
	NSString *description = [NSString stringWithFormat: descriptionFormat, sourceURL.localizedName];
	
	NSMutableDictionary *defaultInfo = [NSMutableDictionary dictionaryWithDictionary: @{
                                                           NSLocalizedDescriptionKey: description,
                                               NSLocalizedRecoverySuggestionErrorKey: suggestion,
                                                                       NSURLErrorKey: sourceURL,
                                        }];
	
	if (userInfo)
        [defaultInfo addEntriesFromDictionary: userInfo];
	
	return [self errorWithDomain: BXSessionErrorDomain
							code: BXImportSourceIsMacOSApp
						userInfo: defaultInfo];
}

- (NSString *) helpAnchor
{
	return @"macos-games";
}
@end


@implementation BXImportDriveUnavailableError

+ (id) errorWithSourceURL: (NSURL *)sourceURL drive: (BXDrive *)drive userInfo: (NSDictionary *)userInfo
{
	NSString *descriptionFormat = NSLocalizedString(@"“%1$@” requires extra files that are currently unavailable.",
                                                    @"Error message shown when importing a folder that has missing drives. %1$@ is the display filename of the imported path.");
	
	NSString *suggestionFormat = NSLocalizedString(@"Please ensure that the resource “%1$@” is available, then retry the import.",
                                                   @"Informative text of warning shown when importing a folder that has missing drives. %1$@ is the missing drive path.");
    
	NSString *description = [NSString stringWithFormat: descriptionFormat, sourceURL.localizedName];
    NSString *suggestion = [NSString stringWithFormat: suggestionFormat, drive.sourceURL.path];
    
	NSMutableDictionary *defaultInfo = [NSMutableDictionary dictionaryWithDictionary: @{
                                                           NSLocalizedDescriptionKey: description,
                                               NSLocalizedRecoverySuggestionErrorKey: suggestion,
                                                                       NSURLErrorKey: drive.sourceURL,
                                        }];
	
	if (userInfo)
        [defaultInfo addEntriesFromDictionary: userInfo];
	
	return [self errorWithDomain: BXSessionErrorDomain
							code: BXImportDriveUnavailable
						userInfo: defaultInfo];
}
@end



@implementation BXGameStateGameboxMismatchError

+ (id) errorWithStateURL: (NSURL *)stateURL gamebox: (BXGamebox *)gamebox userInfo: (NSDictionary *)userInfo
{
	NSString *descriptionFormat = NSLocalizedString(@"“%1$@” contains game data for a different game.",
                                                    @"Error message shown when importing a folder that has missing drives. %1$@ is the display filename of the imported path.");
	
	NSString *suggestionFormat = NSLocalizedString(@"Please provide a game data file that was exported from %1$@.",
                                                   @"Informative text of warning shown when importing a folder that has missing drives. %1$@ is the missing drive path.");
	
    //NSValueTransformer *drivePathFormatter = [[BXDisplayPathTransformer alloc] initWithJoiner: @" ▸ " maxComponents: 0];
    
	NSString *description = [NSString stringWithFormat: descriptionFormat, stateURL.localizedName];
    NSString *suggestion = [NSString stringWithFormat: suggestionFormat, gamebox.gameName];
	
    //[drivePathFormatter release];
    
	NSMutableDictionary *defaultInfo = [NSMutableDictionary dictionaryWithDictionary: @{
                                                           NSLocalizedDescriptionKey: description,
                                               NSLocalizedRecoverySuggestionErrorKey: suggestion,
                                                                       NSURLErrorKey: stateURL
                                        }];
	
	if (userInfo)
        [defaultInfo addEntriesFromDictionary: userInfo];
	
	return [self errorWithDomain: BXSessionErrorDomain
							code: BXGameStateGameboxMismatch
						userInfo: defaultInfo];
}
@end


@implementation BXSessionNotReadyError

+ (id) errorWithUserInfo: (NSDictionary *)userInfo
{
    return [self errorWithDomain: BXSessionErrorDomain code: BXSessionNotReady userInfo: userInfo];
}

@end


@implementation BXSessionURLNotReachableError

+ (id) errorWithURL: (NSURL *)URL userInfo: (NSDictionary *)userInfo
{
    NSMutableDictionary *defaultInfo = [NSMutableDictionary dictionaryWithDictionary: @{
                                         NSURLErrorKey: URL,
                                         }];
	
	if (userInfo)
        [defaultInfo addEntriesFromDictionary: userInfo];
	
    return [self errorWithDomain: BXSessionErrorDomain code: BXURLNotReachableInDOS userInfo: defaultInfo];
}

@end
