/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2010 - 2015 Codeux Software, LLC & respective contributors.
 *       Please see Acknowledgements.pdf for additional information.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 *  * Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 *  * Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *  * Neither the name of Textual, "Codeux Software, LLC", nor the
 *    names of its contributors may be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 *********************************************************************** */

#import "NSObjectHelperPrivate.h"
#import "TPCPreferencesLocal.h"
#import "TVCAppearancePrivate.h"
#import "TVCServerListAppearancePrivate.h"
#import "TVCMainWindow.h"
#import "TVCMainWindowAppearancePrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface TVCMainWindowAppearance ()
@property (nonatomic, weak) TVCMainWindow *mainWindow;
@property (nonatomic, copy, readwrite) NSString *appearanceName;
@property (nonatomic, assign, readwrite) TVCMainWindowAppearanceType appearanceType;
@property (nonatomic, strong, readwrite) TVCServerListAppearance *serverList;
@property (nonatomic, copy, nullable, readwrite) NSColor *titlebarAccessoryViewBackgroundColorActiveWindow;
@property (nonatomic, copy, nullable, readwrite) NSColor *titlebarAccessoryViewBackgroundColorInactiveWindow;
@end

@implementation TVCMainWindowAppearance

#pragma mark -
#pragma mark Initialization

- (nullable instancetype)initWithWindow:(TVCMainWindow *)mainWindow
{
	NSParameterAssert(mainWindow != nil);

	TVCMainWindowAppearanceType appearanceType = [self.class bestAppearanceForWindow:mainWindow];

	NSString *appearanceName = [self.class appearanceNameForType:appearanceType];

	LogToConsoleDebug("Best appearance: %@", appearanceName);

	NSURL *appearanceLocation = [self.class appearanceLocation];

	BOOL forRetinaDisplay = mainWindow.runningInHighResolutionMode;

	if ((self = [super initWithAppearanceNamed:appearanceName atURL:appearanceLocation forRetinaDisplay:forRetinaDisplay])) {
		self.mainWindow = mainWindow;

		self.appearanceName = appearanceName;

		self.appearanceType = appearanceType;

		[self prepareInitialState];

		return self;
	}

	return nil;
}

+ (TVCMainWindowAppearanceType)bestAppearanceForWindow:(TVCMainWindow *)mainWindow
{
	NSParameterAssert(mainWindow != nil);

	BOOL darkMode = [TPCPreferences invertSidebarColors];

	if (TEXTUAL_RUNNING_ON(10.14, Mojave)) {
		if (darkMode) {
			return TVCMainWindowAppearanceMojaveDarkType;
		} else {
			return TVCMainWindowAppearanceMojaveLightType;
		}
	} else if (TEXTUAL_RUNNING_ON(10.10, Yosemite)) {
		if (darkMode) {
			return TVCMainWindowAppearanceYosemiteDarkType;
		} else {
			return TVCMainWindowAppearanceYosemiteLightType;
		}
	}

	if ([NSColor currentControlTint] == NSGraphiteControlTint) {
		if (darkMode) {
			return TVCMainWindowAppearanceMavericksGraphiteDarkType;
		} else {
			return TVCMainWindowAppearanceMavericksGraphiteLightType;
		}
	} else {
		if (darkMode) {
			return TVCMainWindowAppearanceMavericksAquaDarkType;
		} else {
			return TVCMainWindowAppearanceMavericksAquaLightType;
		}
	}
}

+ (nullable NSString *)appearanceNameForType:(TVCMainWindowAppearanceType)type
{
	switch (type) {
		case TVCMainWindowAppearanceMavericksAquaLightType:
		{
			return @"MavericksLightAqua";
		}
		case TVCMainWindowAppearanceMavericksAquaDarkType:
		{
			return @"MavericksDarkAqua";
		}
		case TVCMainWindowAppearanceMavericksGraphiteLightType:
		{
			return @"MavericksLightGraphite";
		}
		case TVCMainWindowAppearanceMavericksGraphiteDarkType:
		{
			return @"MavericksDarkGraphite";
		}
		case TVCMainWindowAppearanceYosemiteLightType:
		{
			return @"YosemiteLight";
		}
		case TVCMainWindowAppearanceYosemiteDarkType:
		{
			return @"YosemiteDark";
		}
		case TVCMainWindowAppearanceMojaveLightType:
		{
			return @"MojaveLight";
		}
		case TVCMainWindowAppearanceMojaveDarkType:
		{
			return @"MojaveDark";
		}
	}

	return nil;
}

+ (NSURL *)appearanceLocation
{
	return [RZMainBundle() URLForResource:@"TVCMainWindowAppearance" withExtension:@"plist"];
}

- (void)prepareInitialState
{
	self.serverList = [[TVCServerListAppearance alloc] initWithServerList:self.mainWindow.serverList parentAppearance:self];

	self.titlebarAccessoryViewBackgroundColorActiveWindow = [self colorForKey:@"titlebarAccessoryViewBackgroundColor" forActiveWindow:YES];
	self.titlebarAccessoryViewBackgroundColorInactiveWindow = [self colorForKey:@"titlebarAccessoryViewBackgroundColor" forActiveWindow:NO];

	[self flushAppearanceProperties];
}

#pragma mark -
#pragma mark Properties

- (nullable TVCMainWindowAppearance *)parentAppearance
{
	return self;
}

- (BOOL)isDarkAppearance
{
	TVCMainWindowAppearanceType appearanceType = self.appearanceType;

	return (appearanceType == TVCMainWindowAppearanceMavericksAquaDarkType ||
			appearanceType == TVCMainWindowAppearanceMavericksGraphiteDarkType ||
			appearanceType == TVCMainWindowAppearanceYosemiteDarkType ||
			appearanceType == TVCMainWindowAppearanceMojaveDarkType);
}

- (BOOL)isModernAppearance
{
	TVCMainWindowAppearanceType appearanceType = self.appearanceType;

	return (appearanceType != TVCMainWindowAppearanceMavericksAquaLightType &&
			appearanceType != TVCMainWindowAppearanceMavericksAquaDarkType &&
			appearanceType != TVCMainWindowAppearanceMavericksGraphiteLightType &&
			appearanceType != TVCMainWindowAppearanceMavericksGraphiteDarkType);
}

@end

NS_ASSUME_NONNULL_END