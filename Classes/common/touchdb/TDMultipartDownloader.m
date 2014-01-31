//
//  TDMultipartDownloader.m
//  TouchDB
//
//  Created by Jens Alfke on 1/31/12.
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.
//
//  Modifications for this distribution by Cloudant, Inc., Copyright (c) 2014 Cloudant, Inc.

#import "TDMultipartDownloader.h"
#import "TDMultipartDocumentReader.h"
#import "TDBlobStore.h"
#import "TDInternal.h"
#import "TDMisc.h"
#import "CollectionUtils.h"


@implementation TDMultipartDownloader


- (id) initWithURL: (NSURL*)url
          database: (TD_Database*)database
    requestHeaders: (NSDictionary *) requestHeaders
      onCompletion: (TDRemoteRequestCompletionBlock)onCompletion
{
    self = [super initWithMethod: @"GET" 
                             URL: url 
                            body: nil
                  requestHeaders: requestHeaders
                    onCompletion: onCompletion];
    if (self) {
        _db = database;
    }
    return self;
}


- (NSString*) description {
    return $sprintf(@"%@[%@]", [self class], _request.URL.path);
}


- (void) setupRequest: (NSMutableURLRequest*)request withBody: (id)body {
    [request setValue: @"multipart/related, application/json" forHTTPHeaderField: @"Accept"];
    request.HTTPBody = body;
}




- (NSDictionary*) document {
    return _reader.document;
}


#pragma mark - URL CONNECTION CALLBACKS:


- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    _reader = [[TDMultipartDocumentReader alloc] initWithDatabase: _db];
    TDStatus status = (TDStatus) ((NSHTTPURLResponse*)response).statusCode;
    if (status < 300) {
        // Check the content type to see whether it's a multipart response:
        NSDictionary* headers = [(NSHTTPURLResponse*)response allHeaderFields];
        NSString* contentType = headers[@"Content-Type"];
        if ([contentType hasPrefix: @"text/plain"])
            contentType = nil;      // Workaround for CouchDB returning JSON docs with text/plain type
        if (![_reader setContentType: contentType]) {
            LogTo(RemoteRequest, @"%@ got invalid Content-Type '%@'", self, contentType);
            [self cancelWithStatus: _reader.status];
            return;
        }
    }
    
    [super connection: connection didReceiveResponse: response];
}


- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [super connection: connection didReceiveData: data];
    if (![_reader appendData: data])
        [self cancelWithStatus: _reader.status];
}


- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    LogTo(SyncVerbose, @"%@: Finished loading (%u attachments)",
          self, (unsigned)_reader.attachmentCount);
    if (![_reader finish]) {
        [self cancelWithStatus: _reader.status];
        return;
    }
    
    [self clearConnection];
    [self respondWithResult: self error: nil];
}


@end
