/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import <Foundation/Foundation.h>
#import <CoreMIDI/MIDIServices.h>
#import "BXMIDIDevice.h"

NS_ASSUME_NONNULL_BEGIN

/// The default seconds-per-byte delay to allow after sending a sysex.
/// Equivalent to the MIDI 1.0 specified delay of 3125 bytes/sec.
#define BXExternalMIDIDeviceDefaultSysexRate (1.0f / 3125.0f)

/// A short delay between programmatically changing the volume and updating the device,
/// to avoid rapid volume changes flooding the device with messages.
#define BXVolumeSyncDelay 0.05

/// BXExternalMIDIDevice represents a connection to an external MIDI device (such as a real MT-32.)
@interface BXExternalMIDIDevice : NSObject <BXMIDIDevice>

/// The destination this device is connecting to. Set at initialization time.
@property (readonly, nonatomic) MIDIEndpointRef destination;

/// Declared as settable for the benefit of our subclasses
@property (copy, readwrite, nonatomic) NSDate *dateWhenReady;

/// The master volume assigned by the application, from 0.0 to 1.0.
@property (assign, nonatomic) float volume;

/// The master volume set by the MIDI-using application via sysex, from 0.0 to 1.0.
/// This will be multiplied by @volume to arrive at the actual volume passed on the device.
@property (assign, nonatomic) float requestedVolume;

@property (assign, nonatomic) NSTimeInterval secondsPerByte;


#pragma mark -
#pragma mark Utility methods

/// The descriptive client and port names to use for MIDI device connections.
/// Has no effect on actual functionality.
@property (class, readonly, copy) NSString *defaultClientName;
@property (class, readonly, copy) NSString *defaultPortName;

/// Returns how many seconds to allow for the external device to process the specified sysex.
/// This is based on the time reported by the destination.
/// Used to calculate dateWhenReady when sending sysex commands.
- (NSTimeInterval) processingDelayForSysex: (NSData *)sysex;

/// Sends specified the sysex message on its way to the external device.
/// Called by handleSysex after volume-related preprocessing, and called instead of handleSysex
/// by certain internal methods in order to bypass that preprocessing. Should not be called
/// directly by other classes unless you know what you're doing.
- (void) dispatchSysex: (NSData *)sysex;


#pragma mark -
#pragma mark Initializers

- (nullable instancetype) initWithDestination: (MIDIEndpointRef)destination
                                        error: (NSError **)outError;

- (nullable instancetype) initWithDestinationAtIndex: (ItemCount)destIndex
                                               error: (NSError **)outError;

- (nullable instancetype) initWithDestinationAtUniqueID: (MIDIUniqueID)uniqueID
                                                  error: (NSError **)outError;

#pragma mark -
#pragma mark Volume control

/// Schedule a volume change to be sent to the device after a suitable delay
/// and once the device is not busy with other sysexes. The delay prevents
/// rapid minor volume changes from flooding the external device.
/// If a volume change is already scheduled, this will have no effect.
- (void) scheduleVolumeSync;

/// Called after a short delay by scheduleVolumeSync, to send the current
/// scaled volume to the external device. Should be overridden by subclasses
/// that need to send custom messages.
- (void) syncVolume;

@end

NS_ASSUME_NONNULL_END
