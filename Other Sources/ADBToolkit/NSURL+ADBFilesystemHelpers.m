/*
 *  Copyright (c) 2013, Alun Bestor (alun.bestor@gmail.com)
 *  All rights reserved.
 *
 *  Redistribution and use in source and binary forms, with or without modification,
 *  are permitted provided that the following conditions are met:
 *
 *		Redistributions of source code must retain the above copyright notice, this
 *	    list of conditions and the following disclaimer.
 *
 *		Redistributions in binary form must reproduce the above copyright notice,
 *	    this list of conditions and the following disclaimer in the documentation
 *      and/or other materials provided with the distribution.
 *
 *	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 *	ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 *	WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 *	IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 *	INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 *	BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,
 *	OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 *	WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 *	ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 *	POSSIBILITY OF SUCH DAMAGE.
 */

#import "NSURL+ADBFilesystemHelpers.h"
#import "ADBForwardCompatibility.h"

@implementation NSURL (ADBFilePaths)

- (NSString *) pathRelativeToURL: (NSURL *)baseURL
{
	//First, standardize both paths.
	baseURL                     = baseURL.URLByStandardizingPath;
	NSURL *originalURL          = self.URLByStandardizingPath;
    
    //Optimisation: if the original URL is already inside the base URL,
    //we can get the relative URL just by snipping off the front of the string.
    if ([originalURL isBasedInURL: baseURL])
    {
        NSUInteger prefixLength = baseURL.path.length;
        NSString *relativePath = [originalURL.path substringFromIndex: prefixLength];
        
        //Check if there's a stray slash on the front and remove that also.
        if ([relativePath hasPrefix: @"/"])
            relativePath = [relativePath substringFromIndex: 1];
        return relativePath;
    }
    //Otherwise, we need to go more in-depth and look at individual path components.
    else
    {
        NSArray *components         = originalURL.pathComponents;
        NSArray *baseComponents     = baseURL.pathComponents;
        NSUInteger numInOriginal	= components.count;
        NSUInteger numInBase        = baseComponents.count;
        NSUInteger from, upTo = MIN(numInBase, numInOriginal);
        
        //Skip over any common prefixes
        for (from=0; from < upTo; from++)
        {
            if (![[components objectAtIndex: from] isEqualToString: [baseComponents objectAtIndex: from]]) break;
        }
        
        NSUInteger i, stepsBack = (numInBase - from);
        NSMutableArray *relativeComponents = [NSMutableArray arrayWithCapacity: stepsBack + numInOriginal - from];
        //First, add the steps to get back to the first common directory
        for (i=0; i<stepsBack; i++) [relativeComponents addObject: @".."];
        //Then, add the steps from there to the original path
        [relativeComponents addObjectsFromArray: [components subarrayWithRange: NSMakeRange(from, numInOriginal - from)]];
        
        return [NSString pathWithComponents: relativeComponents];
    }
}

+ (NSURL *) URLFromFileSystemRepresentation: (const char *)representation
{
    NSURL *theURL = [NSURL fileURLWithFileSystemRepresentation:representation isDirectory:NO relativeToURL:nil];
    if (theURL) {
        return theURL;
    }
    NSFileManager *manager = [[NSFileManager alloc] init];
    NSString *path = [manager stringWithFileSystemRepresentation: representation
                                                          length: strlen(representation)];
    
    return [NSURL fileURLWithPath: path];
}

- (BOOL) isBasedInURL: (NSURL *)baseURL
{
    if (baseURL == nil)
        return NO;
    
    NSString *basePath = baseURL.URLByStandardizingPath.path;
    NSString *originalPath = self.URLByStandardizingPath.path;
    
    if ([originalPath isEqualToString: basePath])
        return YES;
    
    if (![basePath hasSuffix: @"/"])
        basePath = [basePath stringByAppendingString: @"/"];
    
    if (![originalPath hasSuffix: @"/"])
        originalPath = [originalPath stringByAppendingString: @"/"];
    
    return [originalPath hasPrefix: basePath];
}

- (NSArray *) componentURLs
{	
	//Build an array of complete paths for each component of this URL
	NSMutableArray *components = [NSMutableArray arrayWithCapacity: 10];
    
    NSURL *currentURL = self, *parentURL = nil;
	while (YES)
	{
        //NOTE: we insert each component in reverse order
        [components insertObject: currentURL atIndex: 0];
		parentURL = currentURL.URLByDeletingLastPathComponent;
        //We've reached the root once URLByDeletingLastPathComponent
        //returns an identical URL
        if ([parentURL isEqual: currentURL])
            break;
	}
	
    return [components copy];
}

- (NSArray *) URLsByAppendingPaths: (NSArray *)paths
{
    NSMutableArray *URLs = [NSMutableArray arrayWithCapacity: paths.count];
    
    for (NSString *pathComponent in paths)
    {
        NSURL *URL = [self URLByAppendingPathComponent: pathComponent];
        [URLs addObject: URL];
    }
    
    return [URLs copy];
}

@end

@implementation NSURL (ADBResourceValues)

- (id) resourceValueForKey: (NSString *)key
{
    id value;
    BOOL retrieved = [self getResourceValue: &value forKey: key error: NULL];
    if (retrieved)
        return value;
    else
        return nil;
}

- (BOOL) isDirectory
{
    return [[self resourceValueForKey: NSURLIsDirectoryKey] boolValue];
}


- (NSString *) localizedName
{
    return [self resourceValueForKey: NSURLLocalizedNameKey];
}

@end


@implementation NSURL (ADBFileTypes)

+ (NSString *) preferredExtensionForFileType: (NSString *)UTI
{
    CFStringRef extensionForUTI = UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)UTI, kUTTagClassFilenameExtension);
    return CFBridgingRelease(extensionForUTI);
}

+ (NSArray<NSString*> *) fileTypesForExtension: (NSString *)UTI;
{
    CFArrayRef extensionsForUTI = UTTypeCreateAllIdentifiersForTag(kUTTagClassFilenameExtension,
                                                                   (__bridge CFStringRef)UTI,
                                                                   NULL);
    return CFBridgingRelease(extensionsForUTI);
}

+ (NSString *) fileTypeForExtension: (NSString *)extension
{
    CFStringRef UTIForExtension = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension,
                                                                        (__bridge CFStringRef)extension,
                                                                        NULL);
    
    return CFBridgingRelease(UTIForExtension);
}

- (NSString *) typeIdentifier
{
    NSString *UTI = nil;
    BOOL retrievedUTI = [self getResourceValue: &UTI forKey: NSURLTypeIdentifierKey error: NULL];
    if (retrievedUTI)
    {
        return UTI;
    }
    else
    {
        NSString *pathExtension = self.pathExtension;
        if (pathExtension)
        {
            //Attempt to return a UTI based solely on our file extension instead.
            return [self.class fileTypeForExtension: pathExtension];
        }
        else
        {
            return nil;
        }
    }
}
- (BOOL) conformsToFileType: (NSString *)comparisonUTI
{
    NSString *reportedUTI = self.typeIdentifier;
    if (reportedUTI != nil && UTTypeConformsTo((__bridge CFStringRef)reportedUTI, (__bridge CFStringRef)comparisonUTI))
        return YES;
    
    //Also check if the file extension is suitable for the given type, in case an overly generic
    //UTI definition was returned. This has been observed to happen with folder-derived UTIs in
    //10.5-10.8, where NSURLTypeIdentifierKey reports public.folder as the UTI when the extension
    //conforms to a more specific UTI.
    NSString *extension = self.pathExtension;
    if (extension.length)
    {
        NSString *UTIForExtension = [self.class fileTypeForExtension: extension];
        if (UTIForExtension != nil &&
            ![UTIForExtension isEqualToString: reportedUTI] &&
            UTTypeConformsTo((__bridge CFStringRef)UTIForExtension, (__bridge CFStringRef)comparisonUTI))
            return YES;
    }
    
    return NO;
}

- (NSString *) matchingFileType: (NSSet *)UTIs
{
    NSString *reportedUTI = self.typeIdentifier;
    if (reportedUTI != nil)
    {
        for (NSString *comparisonUTI in UTIs)
        {
            if (UTTypeConformsTo((__bridge CFStringRef)reportedUTI, (__bridge CFStringRef)comparisonUTI))
                return comparisonUTI;
        }
    }
    
    //If we couldn't match against the URL's reported UTI, check again against the UTI for the URL's
    //path extension. (See note under conformsToUTI: for details on when this is necessary.)
    NSString *extension = self.pathExtension;
    if (extension.length)
    {
        NSString *UTIForExtension = [self.class fileTypeForExtension: extension];
        if (UTIForExtension != nil && ![UTIForExtension isEqualToString: reportedUTI])
        {
            for (NSString *comparisonUTI in UTIs)
            {
                if (UTTypeConformsTo((__bridge CFStringRef)UTIForExtension, (__bridge CFStringRef)comparisonUTI))
                    return comparisonUTI;
            }
        }
    }
    
    return nil;
}
@end
