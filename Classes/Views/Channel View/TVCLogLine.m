/* ********************************************************************* 
                  _____         _               _
                 |_   _|____  _| |_ _   _  __ _| |
                   | |/ _ \ \/ / __| | | |/ _` | |
                   | |  __/>  <| |_| |_| | (_| | |
                   |_|\___/_/\_\\__|\__,_|\__,_|_|

 Copyright (c) 2008 - 2010 Satoshi Nakagawa <psychs AT limechat DOT net>
 Copyright (c) 2010 - 2015 Codeux Software, LLC & respective contributors.
        Please see Acknowledgements.pdf for additional information.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of Textual and/or "Codeux Software, LLC", nor the 
      names of its contributors may be used to endorse or promote products 
      derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 SUCH DAMAGE.

 *********************************************************************** */

#import "TVCLogLineInternal.h"

#import "TVCLogLineXPCPrivate.h"

NS_ASSUME_NONNULL_BEGIN

NSString * const TVCLogLineUndefinedNicknameFormat = @"<%@%n>";
NSString * const TVCLogLineActionNicknameFormat	= @"%@ ";
NSString * const TVCLogLineNoticeNicknameFormat	= @"-%@-";

NSString * const TVCLogLineSpecialNoticeMessageFormat = @"[%@]: %@";

NSString * const TVCLogLineDefaultCommandValue = @"-100";

@interface TVCLogLine ()
@property (readonly, copy) NSDictionary<NSString *, id> *dictionaryValue;
@end

@implementation TVCLogLine

DESIGNATED_INITIALIZER_EXCEPTION_BODY_BEGIN
- (instancetype)init
{
	ObjectIsAlreadyInitializedAssert

	if ((self = [super init])) {
		if (self->_objectInitializedAsCopy == NO && [self isMutable] == NO) {
			DESIGNATED_INITIALIZER_EXCEPTION
		}

		if (self->_objectInitializedAsCopy == NO) {
			[self populateDefaultsPostflight];

			[self populateDefaultUniqueIdentifier];
			[self populateDefaultSessionIdentifier];
		}

		self->_objectInitialized = YES;

		return self;
	}

	return nil;
}

- (nullable instancetype)initWithData:(NSData *)data
{
	NSParameterAssert(data != nil);

	return [NSKeyedUnarchiver unarchiveObjectWithData:data];
}

+ (TVCLogLine *)logLineFromXPCObject:(TVCLogLineXPC *)xpcObject
{
	NSParameterAssert(xpcObject != nil);

	/* In earlier versions of the historic log database, the unique identifier was
	 not stored in the archived data of the log line. We need a unique identifier now,
	 which the database automatically creates if none is present, but it does it without
	 unarchiving the data because the process does not have this class. It therefore just
	 attaches the unique identifier to the XPC object. We can then write it out here. */
	/* We check if the object's unique identifier is nil before setting the database's
	 value because the value may have already been unarchived if it is present. */
	TVCLogLine *object = [NSKeyedUnarchiver unarchiveObjectWithData:xpcObject.data];

	if (object->_uniqueIdentifier == nil) {
		object->_uniqueIdentifier = [xpcObject.uniqueIdentifier copy];
	}

	if (object->_uniqueIdentifier == nil) {
		[object populateDefaultUniqueIdentifier];
	}

	if (object->_sessionIdentifier == 0) {
		object->_sessionIdentifier = xpcObject.sessionIdentifier;
	}

	return object;
}

- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder
{
	ObjectIsAlreadyInitializedAssert

	if ((self = [super init])) {
		[self decodeWithCoder:aDecoder];

		[self populateDefaultsPostflight];

		self->_objectInitialized = YES;

		return self;
	}

	return nil;
}

- (void)decodeWithCoder:(NSCoder *)aDecoder
{
	NSParameterAssert(aDecoder != nil);

	ObjectIsAlreadyInitializedAssert

	self->_receivedAt = [aDecoder decodeObjectOfClass:[NSDate class] forKey:@"receivedAt"];

	self->_excludeKeywords = [[aDecoder decodeObjectOfClass:[NSArray class] forKey:@"excludeKeywords"] copy];
	self->_highlightKeywords = [[aDecoder decodeObjectOfClass:[NSArray class] forKey:@"highlightKeywords"] copy];

	self->_rendererAttributes = [[aDecoder decodeObjectOfClass:[NSDictionary class] forKey:@"rendererAttributes"] copy];

	self->_isEncrypted = [aDecoder decodeBoolForKey:@"isEncrypted"];

	self->_command = [[aDecoder decodeObjectOfClass:[NSString class] forKey:@"command"] copy];
	self->_messageBody = [[aDecoder decodeObjectOfClass:[NSString class] forKey:@"messageBody"] copy];
	self->_nickname = [[aDecoder decodeObjectOfClass:[NSString class] forKey:@"nickname"] copy];

	self->_lineType = [aDecoder decodeIntegerForKey:@"lineType"];
	self->_memberType = [aDecoder decodeIntegerForKey:@"memberType"];

	self->_uniqueIdentifier = [aDecoder decodeObjectOfClass:[NSString class] forKey:@"uniqueIdentifier"];

	self->_sessionIdentifier = [aDecoder decodeIntegerForKey:@"sessionIdentifier"];

	if (self->_objectInitializedAsCopy == NO) {
		[self computeNicknameColorStyle];
	}
}

- (void)populateDefaultsPostflight
{
	ObjectIsAlreadyInitializedAssert

	SetVariableIfNil(self->_command, TVCLogLineDefaultCommandValue)
	SetVariableIfNil(self->_messageBody, @"")
	SetVariableIfNil(self->_receivedAt, [NSDate date])

	if (self->_lineType == TVCLogLineActionNoHighlightType) {
		self->_lineType = TVCLogLineActionType;

		self->_highlightKeywords = nil;
	} else if (self->_lineType == TVCLogLinePrivateMessageNoHighlightType) {
		self->_lineType = TVCLogLinePrivateMessageType;

		self->_highlightKeywords = nil;
	}
}

- (void)populateDefaultUniqueIdentifier
{
	self->_uniqueIdentifier = [TVCLogLine newUniqueIdentifier];
}

- (void)populateDefaultSessionIdentifier
{
	self->_sessionIdentifier = [TVCLogLine currentSessionIdentifier];
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
	[aCoder encodeObject:self.command forKey:@"command"];
	[aCoder encodeObject:self.messageBody forKey:@"messageBody"];

	[aCoder maybeEncodeObject:self.excludeKeywords forKey:@"excludeKeywords"];
	[aCoder maybeEncodeObject:self.highlightKeywords forKey:@"highlightKeywords"];
	[aCoder maybeEncodeObject:self.rendererAttributes forKey:@"rendererAttributes"];
	[aCoder maybeEncodeObject:self.nickname forKey:@"nickname"];

	[aCoder encodeBool:self.isEncrypted forKey:@"isEncrypted"];

	[aCoder encodeObject:self.receivedAt forKey:@"receivedAt"];

	[aCoder encodeInteger:self.lineType forKey:@"lineType"];
	[aCoder encodeInteger:self.memberType forKey:@"memberType"];

	[aCoder encodeObject:self.uniqueIdentifier forKey:@"uniqueIdentifier"];

	[aCoder encodeInteger:self.sessionIdentifier forKey:@"sessionIdentifier"];
}

+ (BOOL)supportsSecureCoding
{
	return YES;
}

- (TVCLogLineXPC *)xpcObjectForTreeItem:(IRCTreeItem *)treeItem
{
	NSParameterAssert(treeItem != nil);

	NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self];

	TVCLogLineXPC *xpcObject =
	[[TVCLogLineXPC alloc] initWithLogLineData:data
							  uniqueIdentifier:self.uniqueIdentifier
								viewIdentifier:treeItem.uniqueIdentifier
							 sessionIdentifier:self.sessionIdentifier];

	 return xpcObject;
}

+ (NSString *)newUniqueIdentifier
{
	NSString *printIdentifier = [NSString stringWithUUID]; // Example: 68753A44-4D6F-1226-9C60-0050E4C00067

	return [printIdentifier substringFromIndex:19]; // Example: 9C60-0050E4C00067
}

+ (NSUInteger)currentSessionIdentifier
{
	static NSUInteger sessionIdentifier = 0;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		sessionIdentifier = TXRandomNumber(999999);
	});

	return sessionIdentifier;
}

- (BOOL)fromCurrentSession
{
	return (self.sessionIdentifier == [TVCLogLine currentSessionIdentifier]);
}

+ (nullable NSString *)stringForLineType:(TVCLogLineType)type
{
#define _dv(lineType, returnValue)			case (lineType): { return (returnValue); break; }

	switch (type) {
		_dv(TVCLogLineActionType, @"action")
		_dv(TVCLogLineActionNoHighlightType, @"action")
		_dv(TVCLogLineCTCPType, @"ctcp")
		_dv(TVCLogLineCTCPQueryType, @"ctcp")
		_dv(TVCLogLineCTCPReplyType, @"ctcp")
		_dv(TVCLogLineDCCFileTransferType, @"dcc-file-transfer")
		_dv(TVCLogLineDebugType, @"debug")
		_dv(TVCLogLineInviteType, @"invite")
		_dv(TVCLogLineJoinType, @"join")
		_dv(TVCLogLineKickType, @"kick")
		_dv(TVCLogLineKillType, @"kill")
		_dv(TVCLogLineModeType, @"mode")
		_dv(TVCLogLineNickType, @"nick")
		_dv(TVCLogLineNoticeType, @"notice")
		_dv(TVCLogLineOffTheRecordEncryptionStatusType, @"off-the-record-encryption-status")
		_dv(TVCLogLinePartType, @"part")
		_dv(TVCLogLinePrivateMessageType, @"privmsg")
		_dv(TVCLogLinePrivateMessageNoHighlightType, @"privmsg")
		_dv(TVCLogLineQuitType, @"quit")
		_dv(TVCLogLineTopicType, @"topic")
		_dv(TVCLogLineWebsiteType, @"website")

		default:
		{
			return nil;
		}
	}

#undef _dv
}

+ (NSString *)stringForMemberType:(TVCLogLineMemberType)type
{
	if (type == TVCLogLineMemberLocalUserType) {
		return @"myself";
	} else {
		return @"normal";
	}
}

- (nullable NSString *)lineTypeString
{
	return [TVCLogLine stringForLineType:self.lineType];
}

- (NSString *)memberTypeString
{
	return [TVCLogLine stringForMemberType:self.memberType];
}

- (NSString *)formattedTimestamp
{
	return [self formattedTimestampWithFormat:nil];
}

- (NSString *)formattedTimestampWithFormat:(nullable NSString *)format
{
	if (NSObjectIsEmpty(format)) {
		format = themeSettings().themeTimestampFormat;
	}

	if (NSObjectIsEmpty(format)) {
		format = [TPCPreferences themeTimestampFormat];
	}

	if (NSObjectIsEmpty(format)) {
		format = [TPCPreferences themeTimestampFormatDefault];
	}
	
	NSString *time = TXFormattedTimestamp(self.receivedAt, format);

	return time;
}

- (nullable NSString *)formattedNicknameInChannel:(nullable IRCChannel *)channel
{
	return [self formattedNicknameInChannel:channel withFormat:nil];
}

- (nullable NSString *)formattedNicknameInChannel:(nullable IRCChannel *)channel withFormat:(nullable NSString *)format
{
	if (self.nickname == nil) {
		return nil;
	}

	if (format == nil) {
		if (self.lineType == TVCLogLineActionType) {
			return [NSString stringWithFormat:TVCLogLineActionNicknameFormat, self.nickname];
		} else if (self.lineType == TVCLogLineNoticeType) {
			return [NSString stringWithFormat:TVCLogLineNoticeNicknameFormat, self.nickname];
		}
	}

	return [channel.associatedClient formatNickname:self.nickname inChannel:channel withFormat:format];
}

- (NSString *)renderedBodyForTranscriptLog
{
	return [self renderedBodyForTranscriptLogInChannel:nil];
}

- (NSString *)renderedBodyForTranscriptLogInChannel:(nullable IRCChannel *)channel
{
	NSMutableString *s = [NSMutableString string];

	NSString *timeFormatted = [self formattedTimestampWithFormat:TLOFileLoggerISOStandardClockFormat];

	if (timeFormatted) {
		[s appendString:timeFormatted];
		[s appendString:@" "];
	}

	NSString *nicknameFormatted = nil;

	if (self.lineType == TVCLogLineActionType) {
		nicknameFormatted = [self formattedNicknameInChannel:channel withFormat:TLOFileLoggerActionNicknameFormat];
	} else if (self.lineType == TVCLogLineNoticeType) {
		nicknameFormatted = [self formattedNicknameInChannel:channel withFormat:TLOFileLoggerNoticeNicknameFormat];
	} else {
		nicknameFormatted = [self formattedNicknameInChannel:channel withFormat:TLOFileLoggerUndefinedNicknameFormat];
	}

	if (nicknameFormatted) {
		[s appendString:nicknameFormatted];
		[s appendString:@" "];
	}

	[s appendString:self.messageBody];

	return s.stripIRCEffects;
}

- (void)computeNicknameColorStyle
{
	if (self.nickname != nil &&
		(self.lineType == TVCLogLinePrivateMessageType ||
		 self.lineType == TVCLogLinePrivateMessageNoHighlightType ||
		 self.lineType == TVCLogLineActionType ||
		 self.lineType == TVCLogLineActionNoHighlightType))
	{
		BOOL isOverride = NO;

		self->_nicknameColorStyle =
		[IRCUserNicknameColorStyleGenerator nicknameColorStyleForString:self.nickname isOverride:&isOverride];

		self->_nicknameColorStyleOverride = isOverride;
	} else {
		self->_nicknameColorStyle = nil;
	}
}

- (id)copyWithZone:(nullable NSZone *)zone asMutable:(BOOL)copyAsMutable
{
	TVCLogLine *object = nil;

	if (copyAsMutable) {
		object = [TVCLogLineMutable allocWithZone:zone];
	} else {
		object = [TVCLogLine allocWithZone:zone];
	}

	/* All values should be immutable so we are going to reassign 
	 them instead of copying. I should apply logic to other 
	 implementations of -copy in Textual, but that's for another
	 day. TODO: Do that — November 2, 2016 */
	object->_objectInitializedAsCopy = YES;

	object->_uniqueIdentifier = self->_uniqueIdentifier;

	object->_isEncrypted = self->_isEncrypted;

	object->_excludeKeywords = self->_excludeKeywords;
	object->_highlightKeywords = self->_highlightKeywords;

	object->_rendererAttributes = self->_rendererAttributes;

	object->_receivedAt = self->_receivedAt;

	object->_command = self->_command;
	object->_messageBody = self->_messageBody;
	object->_nickname = self->_nickname;
	object->_nicknameColorStyle = self->_nicknameColorStyle;

	object->_nicknameColorStyleOverride = self->_nicknameColorStyleOverride;

	object->_lineType = self->_lineType;
	object->_memberType = self->_memberType;

	object->_sessionIdentifier = self->_sessionIdentifier;

	return [object init];
}

- (id)copyWithZone:(nullable NSZone *)zone
{
	return [self copyWithZone:zone asMutable:NO];
}

- (id)mutableCopyWithZone:(nullable NSZone *)zone
{
	return [self copyWithZone:zone asMutable:YES];
}

- (BOOL)isMutable
{
	return NO;
}

@end

#pragma mark -

@implementation TVCLogLineMutable

@dynamic command;
@dynamic excludeKeywords;
@dynamic highlightKeywords;
@dynamic rendererAttributes;
@dynamic isEncrypted;
@dynamic lineType;
@dynamic memberType;
@dynamic messageBody;
@dynamic nickname;
@dynamic receivedAt;

- (BOOL)isMutable
{
	return YES;
}

- (void)setIsEncrypted:(BOOL)isEncrypted
{
	if (self->_isEncrypted != isEncrypted) {
		self->_isEncrypted = isEncrypted;
	}
}

- (void)setExcludeKeywords:(nullable NSArray<NSString *> *)excludeKeywords
{
	if (self->_excludeKeywords != excludeKeywords) {
		self->_excludeKeywords = [excludeKeywords copy];
	}
}

- (void)setHighlightKeywords:(nullable NSArray<NSString *> *)highlightKeywords
{
	if (self->_highlightKeywords != highlightKeywords) {
		self->_highlightKeywords = [highlightKeywords copy];
	}
}

- (void)setRendererAttributes:(nullable NSDictionary<NSString *, id> *)rendererAttributes
{
	if (self->_rendererAttributes != rendererAttributes) {
		self->_rendererAttributes = [rendererAttributes copy];
	}
}

- (void)setReceivedAt:(NSDate *)receivedAt
{
	NSParameterAssert(receivedAt != nil);

	if (self->_receivedAt != receivedAt) {
		self->_receivedAt = [receivedAt copy];
	}
}

- (void)setCommand:(NSString *)command
{
	NSParameterAssert(command != nil);

	if (self->_command != command) {
		self->_command = [command copy];
	}
}

- (void)setMessageBody:(NSString *)messageBody
{
	NSParameterAssert(messageBody != nil);

	if (self->_messageBody != messageBody) {
		self->_messageBody = [messageBody copy];
	}
}

- (void)setNickname:(nullable NSString *)nickname
{
	if (self->_nickname != nickname) {
		self->_nickname = [nickname copy];

		[self computeNicknameColorStyle];
	}
}

- (void)setMemberType:(TVCLogLineMemberType)memberType
{
	if (self->_memberType != memberType) {
		self->_memberType = memberType;
	}
}

- (void)setLineType:(TVCLogLineType)lineType
{
	if (self->_lineType != lineType) {
		self->_lineType = lineType;
	}
}

@end

NS_ASSUME_NONNULL_END
