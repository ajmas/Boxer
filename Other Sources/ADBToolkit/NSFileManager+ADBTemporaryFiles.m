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


#import "NSFileManager+ADBTemporaryFiles.h"
#import "NSURL+ADBFilesystemHelpers.h"

@implementation NSFileManager (ADBTemporaryFiles)

- (NSURL *) createTemporaryURLWithPrefix: (NSString *)namePrefix error: (out NSError **)outError
{
    NSString *tempPath = NSTemporaryDirectory();
    if (tempPath == nil)
    {
        if (outError)
        {
            *outError = [NSError errorWithDomain: NSCocoaErrorDomain
                                            code: NSFileNoSuchFileError
                                        userInfo: nil];
        }
    }
    
    //Append a mkdtemp()-ready filename pattern in the standard temporary directory, using the specified name prefix
	NSString *nameFormat = [namePrefix stringByAppendingPathExtension: @"XXXXXXXX"];
	NSString *pathFormat = [tempPath stringByAppendingPathComponent: nameFormat];
    
	//Create a character buffer for the path format, which will be rewritten
	CFIndex maxTemplateLength = CFStringGetMaximumSizeOfFileSystemRepresentation((CFStringRef)pathFormat);
	
	char template[maxTemplateLength];
	CFStringGetFileSystemRepresentation((CFStringRef)pathFormat, template, maxTemplateLength);
	
	//Now, actually create the temporary directory. This will write the generated filename back into the buffer.
	char *result = mkdtemp(template);
    
	if (result == NULL)
	{
		if (outError)
        {
            *outError = [NSError errorWithDomain: NSPOSIXErrorDomain
                                            code: errno
                                        userInfo: nil];
        }
		return nil;
	}
	
    //Otherwise, return the final generated URL
	return [NSURL fileURLWithFileSystemRepresentation: template isDirectory: YES relativeToURL: nil];
}

@end
