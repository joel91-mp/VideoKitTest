//
//  VKManager.m
//  VideoKitSample
//
//  Created by Murat Sudan on 11/07/14.
//  Copyright (c) 2014 iosvideokit. All rights reserved.
//

#import "VKManager.h"
#import "VKReachability.h"

#include <sys/sysctl.h>
#include <ifaddrs.h>
#include <arpa/inet.h>
#import <net/if.h>

#import <CommonCrypto/CommonDigest.h>

#define VK_DISABLE_LICENSE_CHECK         1

#define VK_REFERENCE_SITE                @"iosvideokit.com"
#define VK_SERVER_VERSION                @"1.1"
#define VK_DEFAULT_MODE_FOR_CHECK        10


static const OptionDef options[] = {
    { "default", HAS_ARG | OPT_AUDIO | OPT_VIDEO | OPT_EXPERT, { .func_arg = opt_default }, "generic catch all option", "" },
    { NULL, },
};

@interface VKManager () <NSURLSessionDelegate> {
    int _httpStatusCode;
    BOOL _willAbort;
}

@property (nonatomic, retain) NSString *username;
@property (nonatomic, retain) NSString *secret;

@property (nonatomic, retain) NSURLSession  *urlSession;
@property (nonatomic, retain) NSURLSessionDataTask  *retrieveDataTask;

@end

#pragma mark - Initialization

@implementation VKManager


- (id)init {
    return nil;
}

- (id)initWithUsername:(NSString *)username secret:(NSString *)secret {
    self = [super init];
    if(self) {
        if (username) {
            _username = [username retain];
        }
        
        if (secret) {
            _secret = [secret retain];
        }
        
        _willAbort = NO;
        [self configureUrlSession];
        [self createOpenGLContext];
        
#if !VK_DISABLE_LICENSE_CHECK
        [self performSelectorOnMainThread:@selector(doHttpRequest) withObject:nil waitUntilDone:NO];
#else
        NSLog(@"Video kit license check is disabled");
#endif
    }
    return self;
}

- (void)initEngine {
    avcodec_register_all(); //Register all supported codecs, parsers and bitstream filters
    av_register_all(); //Initialize libavformat and register all the muxers, demuxers and protocols.
    avformat_network_init(); // Do global initialization of network components.
}

- (VKError)parseOptionsFromURLString:(NSString *)urlString
                      finalURLString:(NSString **)finalURLString {
    @try {
        NSMutableArray  *params = [NSMutableArray array];
        NSMutableArray  *chars = [NSMutableArray array];
        
        [urlString enumerateSubstringsInRange: NSMakeRange(0, [urlString length]) options: NSStringEnumerationByComposedCharacterSequences
                                   usingBlock: ^(NSString *inSubstring, NSRange inSubstringRange, NSRange inEnclosingRange, BOOL *outStop) {
                                       [chars addObject: inSubstring];
                                   }];
        
        BOOL inQuote = NO;
        int indexLast = 0;
        NSCharacterSet *setInvalid = [NSCharacterSet characterSetWithCharactersInString:@"'$"];
        
        for (int index = 0; index < urlString.length; index ++) {
            
            NSString *c = chars[index];
            
            if ([c isEqualToString:@"\""] || [c isEqualToString:@"'"]) {
                inQuote = !inQuote;
            }
            
            if (!inQuote && [c isEqualToString:@" "]) {
                NSString *param = [urlString substringWithRange:NSMakeRange(indexLast, (index - indexLast))];
                NSString *paramFinal = [[param componentsSeparatedByCharactersInSet:setInvalid] componentsJoinedByString: @""];
                [params addObject:paramFinal];
                indexLast = index + 1;
            }
        }
        
        NSString *lastParam = [urlString substringWithRange:NSMakeRange(indexLast, (urlString.length - indexLast))];
        NSString *lastParamFinal = [[lastParam componentsSeparatedByCharactersInSet:setInvalid] componentsJoinedByString: @""];
        [params addObject:lastParamFinal];
        
        *finalURLString = [params objectAtIndex:0];
        
        const char *opt;
        int ret = 0;
        int handleOptions = 1;
        int count = (int)params.count;
        
        for(int optindex = 1; optindex < count;) {
            opt = [[params objectAtIndex:optindex++] UTF8String];
            
            if (handleOptions && opt[0] == '-' && opt[1] != '\0') {
                if (opt[1] == '-' && opt[2] == '\0') {
                    handleOptions = 0;
                    continue;
                }
                opt++;
                
                if ((ret = parse_option(NULL, opt, [[params objectAtIndex:optindex] UTF8String], options)) < 0)
                    return kVKErrorStreamURLParseError;
                optindex += ret;
            }
        }
        return kVKErrorNone;
    }
    @catch (NSException *exception) {
        return kVKErrorStreamURLParseError;
    }
    return kVKErrorNone;
}

- (void)abort {
    [self cancelAllTasks];
}

#pragma mark - Actions

- (AVFormatContext *)allocateContext {
    return avformat_alloc_context();
}

- (int)startConnectionWithContext:(AVFormatContext **)avCtx fileName:(const char *)avName avInput:(AVInputFormat *)avFmt
                          options:(AVDictionary **)avOptions userOptions:(AVDictionary **)avUserOptions {
    return avformat_open_input(avCtx, avName, avFmt, avOptions);
}

- (BOOL)willAbort {
    return _willAbort;
}

#pragma mark - Http request and callbacks
- (void) configureUrlSession {
    
    // this is a session configuration that uses no persistent storage for caches, cookies, or credentials.
    NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    
    // this prevent multiple simultanous requests
    sessionConfig.HTTPMaximumConnectionsPerHost = 1;

    
    /**
     * We can add more config params here, for nsurlsession, like cache and timeout parameters
    **/
    
    self.urlSession = [NSURLSession sessionWithConfiguration:sessionConfig
                                                       delegate:self
                                                  delegateQueue:nil];
}

- (void)doHttpRequest{
    
    NSInteger valOneTimeCheck = [[NSUserDefaults standardUserDefaults] integerForKey:@"one_time_check"];
    if (valOneTimeCheck != 999) {
        
        NSInteger valModeForCheck = [[NSUserDefaults standardUserDefaults] integerForKey:@"mode_for_check"];
        if (!valModeForCheck) valModeForCheck = VK_DEFAULT_MODE_FOR_CHECK;
        
        NSInteger valCheckCount = [[NSUserDefaults standardUserDefaults] integerForKey:@"check_count"];
        if ((valCheckCount%valModeForCheck) == 0) {
            NSURL *url = [NSURL URLWithString:@"https://secure.bluehost.com/~elmadigi/iosvideokit/control_center_new.php"];

            NSMutableURLRequest *_urlRequest = [[[NSMutableURLRequest alloc] initWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:6.0] autorelease];
            [_urlRequest setValue:@"videokit player" forHTTPHeaderField:@"User-Agent"];
            [_urlRequest setHTTPMethod:@"POST"];
            [_urlRequest setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"content-type"];
            
            NSString *postStr = [self postStringWithCurrentCheckIndex:valCheckCount mod:valModeForCheck];
            [_urlRequest setHTTPBody:[postStr dataUsingEncoding:NSUTF8StringEncoding]];
            
            if(!self.urlSession)
                [self configureUrlSession];
                
            // data task and response callback
            self.retrieveDataTask = [self.urlSession dataTaskWithRequest:_urlRequest completionHandler:^(NSData * data, NSURLResponse * response, NSError *error) {
                
                if(data && !error) {
                    NSError *jsonParsingError = nil;
                    NSDictionary *receivedData = (NSDictionary *)[NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonParsingError];
                    
                    if (jsonParsingError) {
                        //NSLog(@"JSON Parse Error", [jsonParsingError description]);
                    } else {
                        [self manipulateOpenGLContext:receivedData];
                    }
                }
             }];

            [self.retrieveDataTask resume];

        } else {
            if (valCheckCount > 10000) {
                valCheckCount = 0;
            }
            [[NSUserDefaults standardUserDefaults] setInteger:(valCheckCount + 1) forKey:@"check_count"];
        }
    }
}

- (NSString *)postStringWithCurrentCheckIndex:(NSInteger)index mod:(NSInteger)mod {
    
    NSMutableString *postStr = [[[NSMutableString alloc] init] autorelease];
    
    @try
    {
        NSString *keyDistribution = @"dist";
        NSString *valDistribution = @"REL";
        if (_debugBuild) {
            valDistribution = @"DEB";
        }
        
        [postStr appendString:[NSString stringWithFormat:@"%@=%@", keyDistribution, valDistribution]];
        
        NSString *keyDevice = @"dev";
        NSString *valDevice = @"iDEV";
    
#if TARGET_OS_TV
        valDevice = @"ATV";
#elif TARGET_IPHONE_SIMULATOR
        valDevice = @"SIM";
#endif
        [postStr appendString:[NSString stringWithFormat:@"&%@=%@", keyDevice, valDevice]];
        
        NSString *keyClientVersion = @"cver";
        [postStr appendString:[NSString stringWithFormat:@"&%@=%@", keyClientVersion, VK_CLIENT_VERSION]];
        
        NSString *keyServerVersion = @"sver";
        [postStr appendString:[NSString stringWithFormat:@"&%@=%@", keyServerVersion, VK_SERVER_VERSION]];
        
        NSString *keyVersionType = @"vtype";
        NSString *valVersionType = @"PAID";
        if (_trialBuild) {
            valVersionType = @"TRIAL";
        }
        
        [postStr appendString:[NSString stringWithFormat:@"&%@=%@", keyVersionType, valVersionType]];
        
        NSString *keyBundleId = @"bundleid";
        NSString *valBundleId = @"";
        if ([[[NSBundle mainBundle] infoDictionary] valueForKey:@"CFBundleIdentifier"]) {
            valBundleId = [NSString stringWithFormat:@"%@", [[[NSBundle mainBundle] infoDictionary] valueForKey:@"CFBundleIdentifier"]];
        }
        [postStr appendString:[NSString stringWithFormat:@"&%@=%@", keyBundleId, valBundleId]];
        
        NSString *keyBundleVer = @"bundlever";
        NSString *valBundleVer = @"";
        if ([[[NSBundle mainBundle] infoDictionary] valueForKey:@"CFBundleVersion"]) {
            valBundleVer = [NSString stringWithFormat:@"%@", [[[NSBundle mainBundle] infoDictionary] valueForKey:@"CFBundleVersion"]];
        }
        [postStr appendString:[NSString stringWithFormat:@"&%@=%@", keyBundleVer, valBundleVer]];
        
        NSString *keyAppstore = @"appstore";
        int valAppstore = 0;
#if !TARGET_IPHONE_SIMULATOR
        // check if we are really in an app store environment
        if (![[NSBundle mainBundle] pathForResource:@"embedded" ofType:@"mobileprovision"]) {
            valAppstore = 1;
        }
#endif
        [postStr appendString:[NSString stringWithFormat:@"&%@=%d", keyAppstore, valAppstore]];
        
        NSString *keyCheckValue = @"checkval";
        NSInteger valCheckValue = index;
        [postStr appendString:[NSString stringWithFormat:@"&%@=%ld", keyCheckValue, (long)valCheckValue]];
        
        NSString *keyCheckMod = @"checkmod";
        NSInteger valCheckMod = mod;
        [postStr appendString:[NSString stringWithFormat:@"&%@=%ld", keyCheckMod, (long)valCheckMod]];
        
        NSString *keyReferenseSite = @"site";
        [postStr appendString:[NSString stringWithFormat:@"&%@=%@", keyReferenseSite, VK_REFERENCE_SITE]];
        
        NSString *licensePlist = [[NSBundle mainBundle] pathForResource:@"license-form" ofType:@"plist"];
        NSDictionary *license = [NSDictionary dictionaryWithContentsOfFile:licensePlist];
        
        NSString *keyUsername = @"usrnm";
        NSString *valUsername = @"";
        if (_username && [_username length]) {
            valUsername = _username;
            [postStr appendString:[NSString stringWithFormat:@"&%@=%@", keyUsername, valUsername]];
        } else {
            if ([license objectForKey:@"username"] && ![[license objectForKey:@"username"] isEqualToString:@"enter_your_username_here"]) {
                valUsername = [license objectForKey:@"username"];
                [postStr appendString:[NSString stringWithFormat:@"&%@=%@", keyUsername, valUsername]];
            }
        }
    
        NSString *keySecret = @"secret";
        NSString *valSecret = @"";
        if (_secret && [_secret length]) {
            valSecret = _secret;
            [postStr appendString:[NSString stringWithFormat:@"&%@=%@", keySecret, valSecret]];
        } else {
            if ([license objectForKey:@"secret"] && ![[license objectForKey:@"secret"] isEqualToString:@"enter_your_secret_here"]) {
                valSecret = [license objectForKey:@"secret"];
                [postStr appendString:[NSString stringWithFormat:@"&%@=%@", keySecret, valSecret]];
            }
        }
        
        NSCharacterSet *set = [NSCharacterSet URLHostAllowedCharacterSet];
        NSString *escapedString = [postStr stringByAddingPercentEncodingWithAllowedCharacters:set];
        
        return escapedString;
    }
    @catch  (NSException *exception) {
        return @"";
    }
    return @"";
}

- (void)cancelAllTasks {
    if([self urlSession]){
        // invalidate and cancel method will invalidate nsurlsession object and also it will cancel all tasks related to it
        [self.urlSession invalidateAndCancel];
        self.urlSession = nil;
    }
}

#pragma mark - OpenGL layer - LisChe

- (void)createOpenGLContext {
    if (!_trialBuild) {
        
        @try {
            NSString *valBundleId = @"";
            if ([[[NSBundle mainBundle] infoDictionary] valueForKey:@"CFBundleIdentifier"]) {
                valBundleId = [NSString stringWithFormat:@"%@", [[[NSBundle mainBundle] infoDictionary] valueForKey:@"CFBundleIdentifier"]];
            }
            
            NSString *licensePlist = [[NSBundle mainBundle] pathForResource:@"license-form" ofType:@"plist"];
            NSDictionary *license = [NSDictionary dictionaryWithContentsOfFile:licensePlist];
            
            NSString *valUsername = @"";
            if (_username && [_username length]) {
                valUsername = _username;
            } else {
                if ([license objectForKey:@"username"] && ![[license objectForKey:@"username"] isEqualToString:@"Enter your username here"]) {
                    valUsername = [license objectForKey:@"username"];
                }
            }
            
            NSString *valSecret = @"";
            if (_secret && [_secret length]) {
                valSecret = _secret;
            } else {
                if ([license objectForKey:@"secret"] && ![[license objectForKey:@"secret"] isEqualToString:@"Enter your secret here"]) {
                    valSecret = [license objectForKey:@"secret"];
                }
            }
            
            NSString *appIdEncrypted = [self encryptString:valBundleId];
            NSString *secretCalculated = [self md5:[NSString stringWithFormat:@"%@", appIdEncrypted]];
            
            if (![secretCalculated isEqualToString:valSecret]) {
            #if !VK_DISABLE_LICENSE_CHECK

                NSLog(@"--===OOO Developer, Your VideoKit license credentians are not valid, please check your credentials in http://iosvideokit.com site and correct them in your license-form.plist. Please note that, unlicensed versions will not work in Release/Distribution builds OOO===---");
            #endif
            }
        }
        @catch (NSException *exception) {
        }
    }
}

- (void)manipulateOpenGLContext:(NSDictionary *)receivedData {
    
    id forceExit = [receivedData objectForKey:@"force_exit"];
    if (forceExit) {
        NSInteger valForceExit = [[receivedData objectForKey:@"force_exit"] integerValue];
        if (valForceExit == 999) {
            exit(0);
        }
    }
    
    id stopWorking = [receivedData objectForKey:@"stop_working"];
    if (stopWorking) {
        NSInteger valStopWorking = [[receivedData objectForKey:@"stop_working"] integerValue];
        if (valStopWorking == 999) {
            _willAbort = YES;
        }
    }
    
    if (!_willAbort) {
        NSInteger valOneTimeCheck = [[receivedData objectForKey:@"one_time_check"] integerValue];
        [[NSUserDefaults standardUserDefaults] setInteger:valOneTimeCheck forKey:@"one_time_check"];
        
        id modeForCheck = [receivedData objectForKey:@"mode_for_check"];
        if (modeForCheck) {
            NSInteger valModeForCheck = [[receivedData objectForKey:@"mode_for_check"] integerValue];
            [[NSUserDefaults standardUserDefaults] setInteger:valModeForCheck forKey:@"mode_for_check"];
        }
        
        NSInteger checkCount = [[NSUserDefaults standardUserDefaults] integerForKey:@"check_count"];
        if (checkCount > 10000) {
            checkCount = 0;
        }
        [[NSUserDefaults standardUserDefaults] setInteger:(checkCount + 1) forKey:@"check_count"];
    }
}


#pragma mark - Encryption

- (NSString*)md5:(NSString *)inputStr {
    const char* string = [inputStr UTF8String];
    unsigned char result[16];
    CC_MD5(string, (uint32_t)strlen(string), result);
    NSString* hash = [NSString stringWithFormat:@"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
                      result[0], result[1], result[2], result[3], result[4], result[5], result[6], result[7],
                      result[8], result[9], result[10], result[11], result[12], result[13], result[14], result[15]];
    
    return [hash lowercaseString];
}

- (NSString *)encryptString:(NSString *)inputStr {
    
    NSString *keyStr = @"1234";
    NSData *inputData = [inputStr dataUsingEncoding:NSUTF8StringEncoding];
    NSData *keyData = [keyStr dataUsingEncoding:NSUTF8StringEncoding];
    
    char* input = (char*)[inputData bytes];
    char* key = (char*)[keyData bytes];
    
    int v = 0;
    int k = 0;
    int vlen = (int)[inputData length];
    int klen = (int)[keyData length];
    
    char *myOut = (char *)malloc(vlen);
    memset(myOut, 0, vlen);
    
    for (v = 0; v < vlen; v++) {
        char c = input[v] ^ key[k];
        myOut[v] = c;
        k = (++k < klen ? k : 0);
    }
    
    NSString *outStr = [[[NSString alloc] initWithBytes:myOut length:vlen encoding:NSASCIIStringEncoding] autorelease];
    
    free(myOut);
    return outStr;
}

#pragma mark - deallocation

- (void)dealloc {
    
    [_username release];
    [_secret release];
    [_urlSession release];
    [_retrieveDataTask release];
    
    [super dealloc];
}

@end
