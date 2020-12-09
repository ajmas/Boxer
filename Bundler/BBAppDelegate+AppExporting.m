//
//  BBAppDelegate+AppExporting.m
//  Boxer Bundler
//
//  Created by Alun Bestor on 25/08/2012.
//  Copyright (c) 2012 Alun Bestor. All rights reserved.
//

#import "BBAppDelegate+AppExporting.h"
#import "NSURL+ADBFilesystemHelpers.h"
#import "NSImage+ADBSaveImages.h"
#import "BBIconDropzone.h"

NSString * const BBAppExportErrorDomain = @"BBAppExportErrorDomain";
NSString * const BBAppExportCodeSigningIdentityKey = @"BBAppExportCodeSigningIdentityKey";

@implementation BBAppDelegate (AppExporting)

- (void) createAppAtDestinationURL: (NSURL *)destinationURL completion: (void(^)(NSURL *appURL, NSError *error))completionHandler
{
    dispatch_queue_t completionHandlerQueue = dispatch_get_current_queue();
    
    dispatch_queue_t queue = dispatch_queue_create("AppCreationQueue", DISPATCH_QUEUE_SERIAL);
    dispatch_async(queue, ^{
        NSError *creationError = nil;
        NSURL *newAppURL = [self createAppAtDestinationURL: destinationURL
                                                     error: &creationError];
        
        dispatch_sync(completionHandlerQueue, ^{
            completionHandler(newAppURL, creationError);
        });
    });
}

- (NSURL *) createAppAtDestinationURL: (NSURL *)destinationURL
                                error: (NSError **)outError
{
    NSFileManager *manager = [[NSFileManager alloc] init];
    
    NSURL *sourceURL = [[NSBundle mainBundle] URLForResource: @"Boxer Standalone.app" withExtension: nil];
    
    //Make a temporary path in which we can construct the gamebox.
    NSURL *baseTempURL = [manager URLForDirectory: NSItemReplacementDirectory
                                         inDomain: NSUserDomainMask
                                appropriateForURL: destinationURL.URLByDeletingLastPathComponent
                                           create: YES
                                            error: outError];
    
    if (!baseTempURL)
    {
        return nil;
    }
    
    NSURL *tempAppURL = [baseTempURL URLByAppendingPathComponent: destinationURL.lastPathComponent];
    
    BOOL copied = [manager copyItemAtURL: sourceURL toURL: tempAppURL error: outError];
    if (!copied)
    {
        [manager removeItemAtURL: baseTempURL error: NULL];
        return nil;
    }
    
    NSURL *appResourceURL = [tempAppURL URLByAppendingPathComponent: @"Contents/Resources/"];
    
    //Load the application's Info.plist so we can rewrite it with our own data.
    NSURL *appInfoURL = [tempAppURL URLByAppendingPathComponent: @"Contents/Info.plist"];
    NSMutableDictionary *appInfo = [NSMutableDictionary dictionaryWithContentsOfURL: appInfoURL];
    
    
    //Import the gamebox into the new app.
    NSURL *importedGameboxURL = [self _importGameboxFromURL: self.gameboxURL
                                               intoAppAtURL: tempAppURL
                                                   withName: self.sanitisedAppName
                                                 identifier: self.appBundleIdentifier
                                                      error: outError];
    
    if (importedGameboxURL == nil)
    {
        [manager removeItemAtURL: baseTempURL error: NULL];
        return nil;
    }
    
    appInfo[@"BXBundledGameboxName"] = importedGameboxURL.lastPathComponent;
    
    //If an icon has been provided, either copy across the icon file as-is
    //(if it was a valid ICNS-format icon) or recreate an ICNs from the NSImage.
    BOOL hasURLToValidIcon = [self.appIconURL conformsToFileType: (NSString *)kUTTypeAppleICNS];
    
    if (hasURLToValidIcon || self.iconDropzone.image)
    {
        NSURL *iconURL;
        if (hasURLToValidIcon)
            iconURL = [self _applyIconFromURL: self.appIconURL toAppAtURL: tempAppURL error: outError];
        else
            iconURL = [self _applyIcon: self.iconDropzone.image toAppAtURL: tempAppURL error: outError];
        
        if (iconURL == nil)
        {
            [manager removeItemAtURL: baseTempURL error: NULL];
            return nil;
        }
        
        appInfo[@"CFBundleIconFile"] = iconURL.lastPathComponent;
    }
    
    //Fill in various variables in the Info.plist.
    CFTimeZoneRef systemTimeZone = CFTimeZoneCopySystem();
    CFGregorianDate currentDate = CFAbsoluteTimeGetGregorianDate(CFAbsoluteTimeGetCurrent(), systemTimeZone);
    CFRelease(systemTimeZone);
    
    NSString *year = [NSString stringWithFormat: @"%04d", currentDate.year];
    
    NSDictionary *substitutions = @{
                                    @"{{ORGANIZATION_NAME}}":   self.organizationName ?: @"",
                                    @"{{ORGANIZATION_URL}}":    self.organizationURL ?: @"",
                                    @"{{BUNDLE_IDENTIFIER}}":   self.appBundleIdentifier,
                                    @"{{APPLICATION_NAME}}":    self.appName,
                                    @"{{APPLICATION_VERSION}}": self.appVersion,
                                    @"{{YEAR}}":                year
                                    };

    [self _rewritePlist: appInfo withSubstitutions: substitutions];
    
    //Manually replace the version and bundle identifier.
    appInfo[(NSString *)kCFBundleIdentifierKey] = self.appBundleIdentifier;
    appInfo[@"CFBundleShortVersionString"] = self.appVersion;
    
    //Add in the help-menu links.
    NSArray *helpLinks = [self _helpLinksForPlist];
    if (helpLinks.count)
        appInfo[@"BXHelpLinks"] = helpLinks;
    
    
    //Tweak options in the user defaults and game defaults if necessary.
    NSURL *gameDefaultsURL = [appResourceURL URLByAppendingPathComponent: @"GameDefaults.plist"];
    NSMutableDictionary *gameDefaults = [NSMutableDictionary dictionaryWithContentsOfURL: gameDefaultsURL];
        
    gameDefaults[@"mouseButtonModifierRight"] = (self.ctrlClickEnabled) ? @262144 : @0;
    gameDefaults[@"trackMouseWhileUnlocked"] = @(self.seamlessMouseEnabled);
    gameDefaults[@"alwaysShowLaunchPanel"] = @(self.showsLaunchPanelAlways);
    [gameDefaults writeToURL: gameDefaultsURL atomically: YES];
    
    NSURL *userDefaultsURL = [appResourceURL URLByAppendingPathComponent: @"UserDefaults.plist"];
    NSMutableDictionary *userDefaults = [NSMutableDictionary dictionaryWithContentsOfURL: userDefaultsURL];
    userDefaults[@"showHotkeyWarning"] = @(self.showsHotkeyWarning);
    userDefaults[@"showAspectCorrectionToggle"] = @(self.showsAspectCorrectionToggle);
    [userDefaults writeToURL: userDefaultsURL atomically: YES];
    
    
    //Also rewrite the strings files for every localization within the app,
    //to use the substituted app and organization info.
    BOOL rewroteStrings = [self _rewriteStringsFilesInBundleAtURL: appResourceURL
                                                withSubstitutions: substitutions
                                                            error: outError];
    if (!rewroteStrings)
    {
        [manager removeItemAtURL: baseTempURL error: NULL];
        return nil;
    }
    
    NSEnumerator *enumerator = [manager enumeratorAtURL: appResourceURL
                             includingPropertiesForKeys: nil
                                                options: 0
                                           errorHandler: NULL];
    for (NSURL *URL in enumerator)
    {
        if ([URL.pathExtension.lowercaseString isEqualToString: @"strings"])
        {
            BOOL rewrote = [self _rewriteStringsFileAtURL: URL withSubstitutions: substitutions error: outError];
            if (!rewrote)
            {
                [manager removeItemAtURL: baseTempURL error: NULL];
                return nil;
            }
        }
    }
    
    
    //Now let's get to work on the help book.
    NSString *helpbookName = appInfo[@"CFBundleHelpBookFolder"];
    if (helpbookName)
    {
        NSURL *helpbookURL = [appResourceURL URLByAppendingPathComponent: helpbookName];
        
        //Rewrite various variables in the helpbook's own info.plist.
        NSURL *helpbookInfoURL = [helpbookURL URLByAppendingPathComponent: @"Contents/Info.plist"];
        NSURL *helpbookResourceURL = [helpbookURL URLByAppendingPathComponent: @"Contents/Resources/"];
        NSMutableDictionary *helpbookInfo = [NSMutableDictionary dictionaryWithContentsOfURL: helpbookInfoURL];
        
        [self _rewritePlist: helpbookInfo withSubstitutions: substitutions];
        
        //Update the help book's icons.
        if (self.appIconURL)
        {
            NSURL *helpbookIconURL = [self _applyIconFromURL: self.appIconURL
                                             toHelpbookAtURL: helpbookURL
                                                       error: outError];
            
            if (helpbookIconURL == nil)
            {
                [manager removeItemAtURL: baseTempURL error: NULL];
                return nil;
            }
            
            NSString *relativeHelpbookIconPath = [helpbookIconURL pathRelativeToURL: helpbookResourceURL];
            helpbookInfo[@"HPDBookIconPath"] = relativeHelpbookIconPath;
        }
        
        //Write all of our changes to the helpbook's plist back into the helpbook.
        [helpbookInfo writeToURL: helpbookInfoURL atomically: YES];
        
        
        //As with the main bundle, rewrite the strings files for every localization within the helpbook,
        //to use the substituted app and organization info.
        BOOL rewroteHelpbookStrings = [self _rewriteStringsFilesInBundleAtURL: helpbookURL
                                                            withSubstitutions: substitutions
                                                                        error: outError];
        if (!rewroteHelpbookStrings)
        {
            [manager removeItemAtURL: baseTempURL error: NULL];
            return nil;
        }
    }
    
    //TWEAK: if this is to be a branding-less app, remove all resources that may contain branding.
    if (self.isUnbranded)
    {
        NSArray *brandedResources = @[
            @"StandaloneLogo.png",
            @"StandaloneLogo@2x.png",
        ];
        
        for (NSString *resourceName in brandedResources)
        {
            NSURL *resourceURL = [appResourceURL URLByAppendingPathComponent: resourceName];
            [manager removeItemAtURL: resourceURL error: NULL];
        }
    
        [appInfo removeObjectForKey: @"BXOrganizationName"];
        [appInfo removeObjectForKey: @"BXOrganizationWebsiteURL"];
        [appInfo removeObjectForKey: @"NSHumanReadableCopyright"];
    }

    //Write all of our changes to the app's plist back into the app.
    [appInfo writeToURL: appInfoURL atomically: YES];
    
    //Attempt to sign the app using a Gatekeeper-ready Developer ID identity;
    //If that fails, fall back on the standard Mac Developer identity;
    //If that fails, fall back on an ad-hoc identity (which will at least ensure
    //that the code signing is internally consistent, and not whatever broken
    //leftovers are inherited from the Boxer Standalone bundle.)
    //TODO: allow the user to choose the identity from a list or opt-out of signing altogether.
    NSArray *preferredIdentities = @[
                                     @"Developer ID Application",
                                     @"Mac Developer",
                                     @"-",
                                     ];
    
    for (NSString *signingIdentity in preferredIdentities)
    {
        NSError *signingError = nil;
        NSLog(@"Attempting to sign application bundle using '%@' identity...", signingIdentity);
        BOOL codesigned = [self _signBundleAtURL: tempAppURL
                                    withIdentity: signingIdentity
                                           error: &signingError];
        
        //If this identity worked for signing, continue.
        if (codesigned)
        {
            NSLog(@"Application bundle successfully signed with '%@' identity.", signingIdentity);
            break;
        }
        //Otherwise, flag that a signing error occurred and pass the error upstream,
        //but continue trying any remaining identities.
        else
        {
            NSLog(@"Signing failed with '%@' identity: %@", signingIdentity, signingError);
            *outError = signingError;
        }
    }
    
    //Once the app is ready, move the finished and (hopefully) codesigned app
    //from the temporary location to the final destination.
    NSURL *finalDestinationURL = nil;
    BOOL swapped = [manager replaceItemAtURL: destinationURL
                               withItemAtURL: tempAppURL
                              backupItemName: nil
                                     options: 0
                            resultingItemURL: &finalDestinationURL
                                       error: outError];
    
    if (swapped)
    {
        //TODO: once it's in place, update the resulting file's modification date.
        NSError *touchError;
        BOOL touched = [destinationURL setResourceValue: [NSDate date]
                                                 forKey: NSURLContentModificationDateKey
                                                  error: &touchError];
        if (touched)
        {
            NSLog(@"Touched file successfully.");
        }
        else
        {
            NSLog(@"Touch failed with error: %@", touchError);
        }
        
        return finalDestinationURL;
    }
    else
    {
        return nil;
    }
}

- (BOOL) _signBundleAtURL: (NSURL *)bundleURL
             withIdentity: (NSString *)signingIdentity
                    error: (NSError **)outError
{
    //Code-sign the application with the developer's ID, if they have one.
    NSString *codeSignPath = @"/usr/bin/codesign";
    NSArray *codeSignArgs  = @[@"--force",
                               @"--deep",
                               @"--sign",
                               signingIdentity,
                               bundleURL.path];
    
    NSTask *signApp = [[NSTask alloc] init];
    signApp.launchPath = codeSignPath;
    signApp.arguments = codeSignArgs;
    
    NSPipe *errorPipe = [NSPipe pipe];
    signApp.standardError = errorPipe;
    
    [signApp launch];
    [signApp waitUntilExit];
    
    if (signApp.terminationStatus != 0)
    {
        if (outError != NULL)
        {
            NSData *errorData = errorPipe.fileHandleForReading.availableData;
            NSString *errorString = [[NSString alloc] initWithData: errorData encoding: NSUTF8StringEncoding];
            
            *outError = [NSError errorWithDomain: BBAppExportErrorDomain
                                            code: BBAppExportCodeSignFailed
                                        userInfo: @{ NSLocalizedFailureReasonErrorKey: errorString,
                                                     BBAppExportCodeSigningIdentityKey: signingIdentity,
                                                     }];
        }
        
        return NO;
    }
    else return YES;
}

- (NSURL *) _importGameboxFromURL: (NSURL *)gameboxURL
                     intoAppAtURL: (NSURL *)appURL
                         withName: (NSString *)gameboxName
                       identifier: (NSString *)gameIdentifier
                            error: (NSError **)outError
{
    NSFileManager *manager = [[NSFileManager alloc] init];
    
    NSURL *appResourceURL = [appURL URLByAppendingPathComponent: @"Contents/Resources/"];
    
    //Rename the gamebox when importing, if desired
    if (gameboxName == nil)
        gameboxName = gameboxURL.lastPathComponent;
    
    if (![gameboxName.pathExtension isEqualToString: @"boxer"])
        gameboxName = [gameboxName stringByAppendingPathExtension: @"boxer"];
    
    NSURL *destinationURL = [appResourceURL URLByAppendingPathComponent: gameboxName];
    
    BOOL copiedGamebox = [manager copyItemAtURL: self.gameboxURL toURL: destinationURL error: outError];
    if (!copiedGamebox)
    {
        return nil;
    }
    
    //Clean up the gamebox while we're at it: eliminate any custom icon and unhide its file extension.
    [[NSWorkspace sharedWorkspace] setIcon: nil forFile: destinationURL.path options: 0];
    
    [destinationURL setResourceValue: @NO
                              forKey: NSURLHasHiddenExtensionKey
                               error: NULL];
    
    //Modify the gamebox's identifier to the new value, if provided
    if (gameIdentifier != nil)
    {
        NSURL *gameInfoURL = [destinationURL URLByAppendingPathComponent: @"Game Info.plist"];
        NSMutableDictionary *gameInfo = [NSMutableDictionary dictionaryWithContentsOfURL: gameInfoURL];
        gameInfo[@"BXGameIdentifier"] = gameIdentifier;
        gameInfo[@"BXGameIdentifierType"] = @(kBXGameIdentifierReverseDNS);
        [gameInfo writeToURL: gameInfoURL atomically: YES];
    }
    
    return destinationURL;
}


- (NSURL *) _applyIconFromURL: (NSURL *)iconURL
                   toAppAtURL: (NSURL *)appURL
                        error: (NSError **)outError
{
    NSBundle *application = [NSBundle bundleWithURL: appURL];
    
    NSString *iconName = [application objectForInfoDictionaryKey: @"CFBundleIconFile"];
    
    if (iconName == nil)
        iconName = appURL.lastPathComponent.stringByDeletingPathExtension;
    
    if (!iconName.pathExtension.length)
        iconName = [iconName stringByAppendingPathExtension: @"icns"];
    
    NSURL *iconDestinationURL = [application URLForResource: iconName withExtension: nil];
    
    if (!iconDestinationURL) //Existing icon could not be found
        iconDestinationURL = [application.resourceURL URLByAppendingPathComponent: iconName];
    
    NSFileManager *manager = [NSFileManager defaultManager];
    BOOL copiedIcon = [manager copyItemAtURL: iconURL toURL: iconDestinationURL error: outError];
    
    if (copiedIcon)
    {
        return iconDestinationURL;
    }
    else
    {
        return nil;
    }
}

- (NSURL *) _applyIcon: (NSImage *)icon
            toAppAtURL: (NSURL *)appURL
                 error: (NSError **)outError
{
    NSBundle *application = [NSBundle bundleWithURL: appURL];
    NSString *iconName = [application objectForInfoDictionaryKey: @"CFBundleIconFile"];
    
    if (iconName == nil)
        iconName = appURL.lastPathComponent.stringByDeletingPathExtension;
    
    NSURL *iconDestinationURL = [application URLForResource: iconName withExtension: nil];
    
    if (!iconDestinationURL) //Existing icon could not be found
        iconDestinationURL = [application.resourceURL URLByAppendingPathComponent: iconName];
    
    NSFileManager *manager = [NSFileManager defaultManager];
    [manager removeItemAtURL: iconDestinationURL error: NULL];
    
    BOOL savedIcon = [icon saveAsIconToURL: iconDestinationURL error: outError];
    
    if (savedIcon)
    {
        return iconDestinationURL;
    }
    else
    {
        return nil;
    }
}

- (NSURL *) _applyIconFromURL: (NSURL *)iconURL
              toHelpbookAtURL: (NSURL *)helpbookURL
                        error: (NSError **)outError
{
    NSBundle *helpbook = [NSBundle bundleWithURL: helpbookURL];
    NSString *helpbookIconName = [helpbook objectForInfoDictionaryKey: @"HPDBookIconPath"];
    if (helpbookIconName == nil)
    {
        helpbookIconName = @"shared/images/icon.png";
    }
    
    NSString *helpbookIcon2xName = [NSString stringWithFormat: @"%@@2x.%@",
                                    helpbookIconName.stringByDeletingPathExtension,
                                    helpbookIconName.pathExtension];
    
    NSURL *helpbookIconURL = [helpbook URLForResource: helpbookIconName withExtension: nil];
    if (!helpbookIconURL)
        helpbookIconURL = [helpbook.resourceURL URLByAppendingPathComponent: helpbookIconName];
    
    NSURL *helpbookIcon2xURL = [helpbook URLForResource: helpbookIcon2xName withExtension: nil];
    if (!helpbookIcon2xURL)
        helpbookIcon2xURL = [helpbook.resourceURL URLByAppendingPathComponent: helpbookIcon2xName];
    
    //Helpbook icons take a 16x16 and a 32x32 PNG icon, which versions we'll need to extract
    //by force from the original icon file.
    NSImage *icon = [[NSImage alloc] initWithContentsOfURL: iconURL];
    
    NSBitmapImageRep *sourceRep = nil;
    NSBitmapImageRep *source2xRep = nil;
    NSSize targetSize = NSMakeSize(16, 16), target2xSize = NSMakeSize(32, 32);
    
    for (NSBitmapImageRep *rep in icon.representations)
    {
        if (![rep isKindOfClass: [NSBitmapImageRep class]])
            continue;
        
        NSSize size = rep.size;
        //Bingo, we found the 16x16 representations
        if (NSEqualSizes(size, targetSize))
        {
            NSSize pixelSize = NSMakeSize(rep.pixelsWide, rep.pixelsHigh);
            
            //Regular 16x16 icon found!
            if (!sourceRep && NSEqualSizes(pixelSize, targetSize))
            {
                sourceRep = rep;
            }
            else if (!source2xRep && NSEqualSizes(pixelSize, target2xSize))
            {
                source2xRep = rep;
            }
        }
        //Stop looking once we've found good candidates for both resolutions.
        if (sourceRep && source2xRep) break;
    }
    
    if (sourceRep)
    {
        NSData *data = [sourceRep representationUsingType: NSBitmapImageFileTypePNG properties: @{}];
        BOOL wroteIcon = [data writeToURL: helpbookIconURL options: NSAtomicWrite error: outError];
        if (!wroteIcon)
        {
            return nil;
        }
    }
    
    if (source2xRep)
    {
        NSData *data = [source2xRep representationUsingType: NSBitmapImageFileTypePNG properties: @{}];
        BOOL wroteIcon = [data writeToURL: helpbookIcon2xURL options: NSAtomicWrite error: outError];
        if (!wroteIcon)
        {
            return nil;
        }
    }
    return helpbookIconURL;
}

- (BOOL) _rewritePlist: (NSMutableDictionary *)plist
     withSubstitutions: (NSDictionary *)substitutions
{
    for (NSString *key in plist.allKeys)
    {
        id value = [plist valueForKey: key];
        
        if ([value respondsToSelector: @selector(stringByReplacingOccurrencesOfString:withString:)])
        {
            for (NSString *pattern in substitutions)
            {
                NSString *replacement = substitutions[pattern];
                value = [value stringByReplacingOccurrencesOfString: pattern withString: replacement];
            }
            
            plist[key] = value;
        }
    }
    return YES;
}

- (BOOL) _rewriteStringsFilesInBundleAtURL: (NSURL *)bundleURL
                         withSubstitutions: (NSDictionary *)substitutions
                                     error: (NSError **)outError;
{
    NSEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtURL: bundleURL
                                                    includingPropertiesForKeys: nil
                                                                       options: 0
                                                                  errorHandler: NULL];
    for (NSURL *URL in enumerator)
    {
        if ([URL.pathExtension.lowercaseString isEqualToString: @"strings"])
        {
            BOOL rewrote = [self _rewriteStringsFileAtURL: URL withSubstitutions: substitutions error: outError];
            //Bail out if any read/write errors are encountered
            if (!rewrote)
                return NO;
        }
    }
    return YES;
}

- (BOOL) _rewriteStringsFileAtURL: (NSURL *)stringsURL
                withSubstitutions: (NSDictionary *)substitutions
                            error: (NSError **)outError;
{
    NSStringEncoding originalEncoding;
    NSString *contentsOfStringsFile = [NSString stringWithContentsOfURL: stringsURL
                                                           usedEncoding: &originalEncoding
                                                                  error: outError];
    if (contentsOfStringsFile != nil)
    {
        NSMutableString *rewrittenString = [NSMutableString stringWithString: contentsOfStringsFile];
        for (NSString *pattern in substitutions)
        {
            NSString *replacement = substitutions[pattern];
            [rewrittenString replaceOccurrencesOfString: pattern
                                             withString: replacement
                                                options: NSLiteralSearch
                                                  range: NSMakeRange(0, rewrittenString.length)];
        }
        
        return [rewrittenString writeToURL: stringsURL
                                atomically: YES
                                  encoding: originalEncoding
                                     error: outError];
    }
    else
    {
        return NO;
    }
}

- (NSArray *) _helpLinksForPlist
{
    NSMutableArray *helpLinks = [NSMutableArray arrayWithCapacity: self.helpLinks.count];
    for (NSDictionary *linkInfo in self.helpLinks)
    {
        //Ignore incomplete help links
        NSString *title = linkInfo[@"title"], *url = linkInfo[@"url"];
        if (!title || !url)
            continue;
        
        NSDictionary *plistVersion = @{
            @"BXHelpLinkTitle": title,
            @"BXHelpLinkURL": url
        };
        
        [helpLinks addObject: plistVersion];
    }
    return helpLinks;
}

@end
