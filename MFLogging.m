//
//  MFLoggingController.m
//  MacFusion2
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//      http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "MFLogging.h"
#import "MFFilesystem.h"
#import "MFLogReader.h"
#import "MFServerProtocol.h"
#import "MFConstants.h"
#import "MFClient.h"

#define LOG_FILE_PATH @"~/Library/Logs/MacFusion2.log"

// Print to logging system
void MFLog(NSString *format, ...) {
	MFLogging *logger = [MFLogging sharedLogging];
	
	// get a reference to the arguments on the stack that follow
    // the format paramter
    va_list argList;
    va_start (argList, format);
	
    // NSString luckily provides us with this handy method which
    // will do all the work for us, including %@
    NSString *string;
    string = [[NSString alloc] initWithFormat:format arguments:argList];
    va_end (argList);
	[logger logMessage:string ofType:0 object:nil sender:@"MFCORE"]; 
}


void MFLogP(int type, NSString *format, ...) {
	MFLogging *logger = [MFLogging sharedLogging];
	
	// get a reference to the arguments on the stack that follow
    // the format paramter
    va_list argList;
    va_start (argList, format);
	
    // NSString luckily provides us with this handy method which
    // will do all the work for us, including %@
    NSString *string = [[NSString alloc] initWithFormat:format arguments: argList];
    va_end(argList);
	[logger logMessage:string ofType:type object: nil sender:nil]; 
}

void MFLogS(id sender, NSString *format, ...) {
	MFLogging *logger = [MFLogging sharedLogging];
	
	// get a reference to the arguments on the stack that follow
    // the format paramter
    va_list argList;
    va_start (argList, format);
	
    // NSString luckily provides us with this handy method which
    // will do all the work for us, including %@
    NSString *string = [[NSString alloc] initWithFormat: format arguments: argList];
    va_end  (argList);
	[logger logMessage:string ofType:0 object:nil sender:sender]; 
}

void MFLogSO(id sender, id object, NSString *format, ...) {
	MFLogging *logger = [MFLogging sharedLogging];
	
	// get a reference to the arguments on the stack that follow
    // the format paramter
    va_list argList;
    va_start (argList, format);
	
    // NSString luckily provides us with this handy method which
    // will do all the work for us, including %@
    NSString *string = [[NSString alloc] initWithFormat:format arguments:argList];
    va_end (argList);
	[logger logMessage:string ofType:0 object:object sender:sender]; 
}

// Print directly to console
void MFPrint(NSString *format, ...) {
	// get a reference to the arguments on the stack that follow
    // the format paramter
    va_list argList;
    va_start (argList, format);
	
    // NSString luckily provides us with this handy method which
    // will do all the work for us, including %@
    NSString *string;
    string = [[NSString alloc] initWithFormat:format arguments:argList];
    va_end  (argList);
	printf("%s\n", [string cStringUsingEncoding:NSASCIIStringEncoding]);
}


@implementation MFLogging

static MFLogging *sharedLogging = nil;

+ (MFLogging *)sharedLogging {
	if (sharedLogging == nil) {
		[[self alloc] init];
	}
	
	return sharedLogging;
}

+ (id)allocWithZone:(NSZone *)zone {
	if (sharedLogging == nil) {
		sharedLogging = [super allocWithZone:zone];
		return sharedLogging;
	}
	
	return nil;
}

- (id)init {
	if (self = [super init]) {
		fd = -1;
		stdOut = YES;
		formatter = [NSDateFormatter new];
		[formatter setDateStyle:NSDateFormatterShortStyle];
		[formatter setTimeStyle: NSDateFormatterShortStyle];
	}
	
	return self;
}

- (void)setupLogFile {
	aslClient = asl_open(NULL, MF_ASL_SERVICE_NAME, 0);
	
	fd = open( [[LOG_FILE_PATH stringByExpandingTildeInPath] cStringUsingEncoding: NSUTF8StringEncoding],
			  O_CREAT | O_WRONLY | O_APPEND, S_IRUSR | S_IWUSR );
	asl_add_log_file(aslClient, fd);
	asl_set_filter(aslClient, ASL_FILTER_MASK_UPTO(ASL_LEVEL_INFO));
}

NSDictionary *dictFromASLMessage(aslmsg m) {
	NSMutableDictionary *messageDict = [NSMutableDictionary dictionary];
	NSInteger i;
	const char *key;
	const char *val;
	for (i = 0; (NULL != (key = asl_key(m, i))); i++) {
		val = asl_get(m, key);
		if (key && val) {
			[messageDict setObject:[[NSString alloc] initWithUTF8String:val]
							forKey:[[NSString alloc] initWithUTF8String:key]];	
		}
	}
	
	if (![messageDict objectForKey:kMFLogKeyTime]) {
		[messageDict setObject:[NSNumber numberWithInt:[[NSDate date] timeIntervalSince1970]] forKey:kMFLogKeyTime];
	}
	return [messageDict copy];
}

- (NSDateFormatter*)formatter {
	return formatter;
}

NSString *headerStringForASLMessageDict(NSDictionary *messageDict) {
	MFLogging *self = [MFLogging sharedLogging];
	NSMutableArray* headerList = [NSMutableArray array];
	NSString *sender = [messageDict objectForKey:kMFLogKeySender];
	NSString *uuid = [messageDict objectForKey:kMFLogKeyUUID];
	NSString *subsystem = [messageDict objectForKey:kMFLogKeySubsystem];
	NSString *uuidFSName = uuid ? [[[self delegate] filesystemWithUUID:uuid] name] : nil;
	NSDate *date = [NSDate dateWithTimeIntervalSince1970:[[messageDict objectForKey:kMFLogKeyTime] intValue]];;
	NSString *formattedDate = [[self formatter] stringFromDate:date];
	
	if (sender) {
		[headerList addObject:sender];	
	}
	
	if (subsystem) {
		[headerList addObject: subsystem];
	}
		
	if (uuidFSName) {
		[headerList addObject: uuidFSName];
	}
		
	if (formattedDate || [formattedDate length] > 0) {
		[headerList addObject: formattedDate];
	}
		
	
	// NSLog(@"Formatted date %@", formattedDate);
	NSString* header = [NSString stringWithFormat: @"(%@)", [headerList componentsJoinedByString: @", "]];
	return header;
}

- (void)sendASLMessageDictOverDO:(NSDictionary*)messageDict {
	id <MFServerProtocol> server = 
	(id<MFServerProtocol>)[NSConnection rootProxyForConnectionWithRegisteredName:kMFDistributedObjectName host:nil];
	
	if (server) 	{
		[server sendASLMessageDict:messageDict];
	}
}

- (void)logMessage:(NSString*)message ofType:(NSInteger)type object:(id)object sender:(id)sender {
	if (fd == -1) {
		[self setupLogFile];
	}
		
	
	message = [message stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	aslmsg newASLMessage = asl_new(ASL_TYPE_MSG);
	asl_set(newASLMessage, ASL_KEY_FACILITY, MF_ASL_SERVICE_NAME);
	if ([sender isKindOfClass: [MFFilesystem class]]) {
		asl_set(newASLMessage, ASL_KEY_UUID, [[(MFFilesystem*)sender uuid] UTF8String]);
	}
	if ([object isKindOfClass: [MFFilesystem class]]) {
		asl_set(newASLMessage, ASL_KEY_UUID, [[(MFFilesystem*)object uuid] UTF8String]);
	}
	asl_set(newASLMessage, ASL_KEY_SUBSYSTEM, [[[sender class] description] UTF8String]);
	asl_set(newASLMessage, ASL_KEY_MSG, [message UTF8String]);
	asl_log(aslClient, newASLMessage, ASL_LEVEL_ERR, "%s", [message UTF8String]);
	
	// Send to other macfusion system processes over DO
	NSDictionary *messageDict = dictFromASLMessage(newASLMessage);
	asl_free(newASLMessage);
	[self sendASLMessageDictOverDO:messageDict];
}


- (void)setPrintToStandardOut:(BOOL)b {
	stdOut = b;
}

- (void)finalize {
	asl_close(aslClient);
	close(fd);
	[super finalize];
}

@synthesize delegate;

@end
