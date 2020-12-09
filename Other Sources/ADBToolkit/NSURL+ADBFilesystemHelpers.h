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

//These categories extend NSURL (and NSArray) to add a few helpful methods for dealing
//with file URLs and Uniform Type Identifiers.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSURL (ADBFilePaths)

/// Returns a path for this URL that's relative to the specified file URL,
/// producing the following results:
/// - /foo/bar relative to / becomes @"foo/bar"
/// - /foo/bar relative to /foo/bar becomes @""
/// - /foo/bar relative to /foo becomes @"bar"
/// - /foo/bar relative to /foo/baz becomes @"../bar"
/// - /foo/bar relative to /baz becomes @"../foo/bar"
/// - /foo/bar relative to /baz/bla becomes @"../../foo/bar"
///
/// That is, the resulting string can be appended to the base URL with URLByAppendingPathComponent:
/// to form an absolute URL to the original resource.
- (NSString *) pathRelativeToURL: (NSURL *)baseURL;

/// Convert a URL to/from a local filesystem path representation.
+ (NSURL *) URLFromFileSystemRepresentation: (const char *)representation;

/// Whether this URL has the specified file URL as an ancestor.
- (BOOL) isBasedInURL: (NSURL *)baseURL;

/// An analogue for NSString pathComponents:
/// Returns an array containing this URL and every parent directory leading back to the root.
@property (readonly, copy) NSArray<NSURL*> *componentURLs;

/// An analogue for NSString stringsByAppendingPaths:
- (NSArray<NSURL*> *) URLsByAppendingPaths: (NSArray<NSString*> *)paths;

@end


@interface NSURL (ADBResourceValues)

/// Returns the value for the specified resource property.
/// Returns nil if the property cannot be retrieved for any reason.
/// This is just a simpler calling syntax for NSURL getResourceValue:forKey:error:
/// for when you don't care about failure reasons.
- (nullable id) resourceValueForKey: (NSURLResourceKey)key;

/// Returns the localized display name of the file: i.e., the value of NSURLLocalizedNameKey.
@property (readonly, copy, nullable) NSString *localizedName;

/// Returns whether this URL represents a directory: i.e. the value of NSURLIsDirectoryKey.
@property (readonly, getter=isDirectory) BOOL directory;

@end


@interface NSURL (ADBFileTypes)

/// Returns the UTI of the file at this URL, or @c nil if this could not be determined.
@property (readonly, nonatomic, nullable) NSString *typeIdentifier;

/// Returns @c YES if the Uniform Type Identifier for the file at this URL is equal to or inherits
/// from the specified UTI, or if the URL has a path extension that would be suitable for the specified UTI.
- (BOOL) conformsToFileType: (NSString *)UTI;

/// Given a set of Uniform TypeIdentifiers, returns the first one to which this URL conforms,
/// or @c nil if it doesn't match any of them.
- (nullable NSString *) matchingFileType: (NSSet<NSString*> *)UTIs;

/// Returns the recommended file extension to use for files of the specified type.
/// Analogous to NSWorkspace preferredExtensionForFileType:.
+ (nullable NSString *) preferredExtensionForFileType: (NSString *)UTI;

/// Returns all of the UTIs that use the specified extension.
+ (nullable NSArray<NSString*> *) fileTypesForExtension: (NSString *)UTI;

/// Returns the UTI most applicable to files with the specified extension.
+ (nullable NSString *) fileTypeForExtension: (NSString *)extension;
@end

NS_ASSUME_NONNULL_END
