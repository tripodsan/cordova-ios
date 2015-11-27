/*
 Licensed to the Apache Software Foundation (ASF) under one
 or more contributor license agreements.  See the NOTICE file
 distributed with this work for additional information
 regarding copyright ownership.  The ASF licenses this file
 to you under the Apache License, Version 2.0 (the
 "License"); you may not use this file except in compliance
 with the License.  You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing,
 software distributed under the License is distributed on an
 "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 KIND, either express or implied.  See the License for the
 specific language governing permissions and limitations
 under the License.
 */


#import "CDVURLProtocolHttp.h"

@interface CDVURLProtocolHttp()

    @property (nonatomic, strong) NSURLConnection *connection;

@end

/**
 * Generic protocol to handle http and https requests.
 * Currently only used to suppress the "www-authenticate" response header, in order to avoid the
 * authentication pop-up to show up (see CB-2415).
 */
@implementation CDVURLProtocolHttp

#define KEY_BYPASS_OWN_PROTOCOL @"cdv-no-http-protocol"

/**
 * We handle the request for http and https, but only if we not already initialized the connection.
 */
+ (BOOL) canInitWithRequest:(NSURLRequest*) request {
    if (![request.URL.scheme isEqualToString:@"http"] && ![request.URL.scheme isEqualToString:@"https"]) {
        return NO;
    }


    static NSUInteger requestCount = 0;

    if ([NSURLProtocol propertyForKey:KEY_BYPASS_OWN_PROTOCOL inRequest:request]) {
        NSLog(@"NO  Request #%u: URL = %@", requestCount++, request);
        return NO;
    }
    // TODO: only handle for ajax request, i.e. if 'x-requested-with' == 'XMLHttpRequest'

    NSLog(@"YES Request #%u: URL = %@", requestCount++, request);
    return YES;

}

+ (NSURLRequest*) canonicalRequestForRequest:(NSURLRequest*) request {
    return request;
}

+ (BOOL)requestIsCacheEquivalent:(NSURLRequest *)a toRequest:(NSURLRequest *)b {
    return [super requestIsCacheEquivalent:a toRequest:b];
}

- (id)initWithRequest:(NSURLRequest *)request cachedResponse:(NSCachedURLResponse *)cachedResponse client:(id <NSURLProtocolClient>)client
{
    self = [super initWithRequest:request cachedResponse:cachedResponse client:client];
    NSLog(@"initWithRequest self=%@, req=%@ resp=%@", self, request, cachedResponse);
    return self;
}

/**
 * Start loading the request.
 *
 * We use our own connection to load the request, so that we can intercept the response headers.
 */
- (void) startLoading {
    NSLog(@"start loading %@", self.request.URL);

    // mark the request as handled
    NSMutableURLRequest* request = self.request.mutableCopy;
    [NSURLProtocol setProperty:@YES forKey:KEY_BYPASS_OWN_PROTOCOL inRequest:request];

    // create connection
    self.connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
    [self.connection scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    [self.connection start];
}

/**
 * Stop loading the request.
 */
- (void) stopLoading {
    NSLog(@"stop loading %@", self.request.URL);
    [self.connection cancel];
    self.connection = nil;
}

#pragma mark NSURLConnection Delegate Methods


- (void) connection:(NSURLConnection*) connection didReceiveData:(NSData*) data {
    NSLog(@"did receive data self=%@ %@", self, self.request.URL);
    [self.client URLProtocol:self didLoadData:data];
}

- (void) connection:(NSURLConnection*) connection didFailWithError:(NSError*) error {
    NSLog(@"did didFailWithError  self=%@ error=%@ %@", self, error, self.request.URL);
    [self.client URLProtocol:self didFailWithError:error];
}

/**
 * Handles the response by altering response headers for 401 responses. It removes the
 * 'www-authenticate' header so that the webview will no open the credentials prompt.
 */
- (void) connection:(NSURLConnection*) connection didReceiveResponse:(NSURLResponse*) response {
    NSLog(@"did didReceiveResponse  self=%@ resp=%@ %@", self, response, self.request.URL);
    NSURLCacheStoragePolicy policy = NSURLCacheStorageAllowed;
    if ([response isKindOfClass:NSHTTPURLResponse.class]) {
        NSHTTPURLResponse* resp = (NSHTTPURLResponse*) response;
        if (resp.statusCode == 401) {
//            // remove www-authenticate header
//            NSMutableDictionary* headers = [resp allHeaderFields].mutableCopy;
//            [headers removeObjectForKey:@"WWW-Authenticate"];
//            response = [[NSHTTPURLResponse alloc] initWithURL:resp.URL
//                                                   statusCode:resp.statusCode
//                                                  HTTPVersion:@"1.1"
//                                                 headerFields:headers
//            expecte];
            policy = NSURLCacheStorageNotAllowed;
        }
    }
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:policy];
}

- (void) connectionDidFinishLoading:(NSURLConnection*) connection {
    [self.client URLProtocolDidFinishLoading:self];
}

- (NSURLRequest*) connection:(NSURLConnection*) connection willSendRequest:(NSURLRequest*) request redirectResponse:(NSURLResponse*) response {
    NSLog(@"willSendRequest self=%@ request=%@ response=%@", self, request, response);
    return request;
}

- (NSInputStream*) connection:(NSURLConnection*) connection needNewBodyStream:(NSURLRequest*) request {
    NSLog(@"needNewBodyStream self=%@ request=%@", self, request);
    return nil;
}

- (void) connection:(NSURLConnection*) connection didSendBodyData:(NSInteger) bytesWritten totalBytesWritten:(NSInteger) totalBytesWritten totalBytesExpectedToWrite:(NSInteger) totalBytesExpectedToWrite {
    NSLog(@"didSendBodyData self=%@ ", self);

}

- (NSCachedURLResponse*) connection:(NSURLConnection*) connection willCacheResponse:(NSCachedURLResponse*) cachedResponse {
    NSLog(@"willCacheResponse self=%@ resp=%@", self, cachedResponse);
    return cachedResponse;
}


- (BOOL) connectionShouldUseCredentialStorage:(NSURLConnection*) connection {
    return NO;
}

- (BOOL) connection:(NSURLConnection*) connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace*) protectionSpace {
    NSLog(@"canAuthenticateAgainstProtectionSpace self=%@ space=%@", self, protectionSpace);
    return NO;
}

- (void) connection:(NSURLConnection*) connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge*) challenge {
    NSLog(@"didReceiveAuthenticationChallenge self=%@ challange=%@", self, challenge);

}

- (void) connection:(NSURLConnection*) connection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge*) challenge {
    NSLog(@"willSendRequestForAuthenticationChallenge self=%@ challange=%@", self, challenge);

}

- (void) connection:(NSURLConnection*) connection didCancelAuthenticationChallenge:(NSURLAuthenticationChallenge*) challenge {
    NSLog(@"didCancelAuthenticationChallenge self=%@ challange=%@", self, challenge);
}

@end
