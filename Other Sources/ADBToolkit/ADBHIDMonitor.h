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


#import <Foundation/Foundation.h>
#import <IOKit/hid/IOHIDLib.h>


NS_ASSUME_NONNULL_BEGIN

#pragma mark -
#pragma mark Notification constants

//Posted to the NSWorkspace notification center when an HID device is added or removed.
extern NSNotificationName const ADBHIDDeviceAdded;
extern NSNotificationName const ADBHIDDeviceRemoved;

/// Included in the userInfo dictionary for above notifications.
/// Value is a \c DDHIDDevice subclass corresponding to the device that was added/removed.
extern NSString * const ADBHIDDeviceKey;


@class DDHidDevice;
@protocol ADBHIDMonitorDelegate;

/// @c ADBHIDMonitor subscribes to HID input messages from DDHIDLib and IOKit and posts notifications
/// when devices are added or removed.
@interface ADBHIDMonitor: NSObject
{
	IOHIDManagerRef _ioManager;
	NSMutableDictionary<NSNumber*,DDHidDevice*> *_knownDevices;
	__weak id <ADBHIDMonitorDelegate> _delegate;
}

#pragma mark -
#pragma mark Properties

/// The devices enumerated by this input manager,
/// matching the criteria specified to observeDevicesMatching:
@property (copy, readonly, nonatomic) NSArray<DDHidDevice*> *matchedDevices;

/// This delegate will receive messages directly whenever devices are added or removed.
@property (weak, nonatomic, nullable) id <ADBHIDMonitorDelegate> delegate;


#pragma mark -
#pragma mark Helper class methods

//Descriptors to feed to observeDevicesMatching:
@property (class, readonly) NSDictionary<NSString*,NSNumber*> *joystickDescriptor;
@property (class, readonly) NSDictionary<NSString*,NSNumber*> *gamepadDescriptor;
@property (class, readonly) NSDictionary<NSString*,NSNumber*> *mouseDescriptor;
@property (class, readonly) NSDictionary<NSString*,NSNumber*> *keyboardDescriptor;


#pragma mark -
#pragma mark Device observation

/// Observe HID devices matching the specified criteria.
/// Calling this multiple times will replace the previous criteria
/// and repopulate matchedDevices.
///
/// Descriptors should be specified as an array of NSDictionaries,
/// according the syntax of IOHIDManagerSetDeviceMatchingMultiple().
/// Pass @c nil for descriptors to match all HID devices.
- (void) observeDevicesMatching: (nullable NSArray<NSDictionary<NSString*,NSNumber*>*> *)descriptors;

/// Stop observing HID devices. This will empty matchedDevices.
- (void) stopObserving;

/// Called when the specified device is connected, or is already
/// connected when observeDevicesMatching: is called.
/// Intended to be overridden by subclasses.
- (void) deviceAdded: (DDHidDevice *)device;

/// Called when the specified device is removed.
/// Intended to be overridden by subclasses.
- (void) deviceRemoved: (DDHidDevice *)device;

@end


@protocol ADBHIDMonitorDelegate <NSObject>

@optional
- (void) monitor: (ADBHIDMonitor *)monitor didAddHIDDevice: (DDHidDevice *)device;
- (void) monitor: (ADBHIDMonitor *)monitor didRemoveHIDDevice: (DDHidDevice *)device;

@end

NS_ASSUME_NONNULL_END
