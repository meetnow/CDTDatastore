//
//  CDTReplicatorFactory.m
//  
//
//  Created by Michael Rhodes on 10/12/2013.
//  Copyright (c) 2013 Cloudant. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import "CDTReplicatorFactory.h"

#import "CDTDatastoreManager.h"
#import "CDTDatastore.h"
#import "CDTReplicator.h"
#import "CDTAbstractReplication.h"
#import "CDTPullReplication.h"
#import "CDTPushReplication.h"
#import "CDTDocumentRevision.h"
#import "CDTDocumentBody.h"

#import "TDReplicatorManager.h"

static NSString* const CDTReplicatorFactoryErrorDomain = @"CDTReplicatorFactoryErrorDomain";


@interface CDTReplicatorFactory ()

@property (nonatomic,strong) CDTDatastoreManager *manager;

@property (nonatomic,strong) TDReplicatorManager *replicatorManager;

@end

@implementation CDTReplicatorFactory

#pragma mark Manage our TDReplicatorManager instance

- (id) initWithDatastoreManager: (CDTDatastoreManager*)dsManager {

    self = [super init];
    if (self) {
        self.manager = dsManager;
        TD_DatabaseManager *dbManager = dsManager.manager;
        self.replicatorManager = [[TDReplicatorManager alloc] initWithDatabaseManager:dbManager];
    }
    return self;
}

- (void) start {
    [self.replicatorManager start];
}

- (void) stop {
    [self.replicatorManager stop];
}

#pragma mark CDTReplicatorFactory interface methods

- (CDTReplicator*)onewaySourceDatastore:(CDTDatastore*)source
                              targetURI:(NSURL*)target {
    
    CDTPushReplication *push = [CDTPushReplication replicationWithSource:source target:target];

    return [self oneWay:push error:nil];
}

- (CDTReplicator*)onewaySourceURI:(NSURL*)source
                  targetDatastore:(CDTDatastore*)target {

    CDTPullReplication *pull = [CDTPullReplication replicationWithSource:source target:target];
    
    return [self oneWay:pull error:nil];
}


- (CDTReplicator*)oneWay:(CDTAbstractReplication*)replication
                   error:(NSError * __autoreleasing *)error
{
    
    NSError *localErr;
    NSDictionary *repdoc = [replication dictionaryForReplicatorDocument:&localErr];
    if (localErr) {
        if (error) *error = localErr;
        return nil;
    }
    
    CDTDocumentBody *body = [[CDTDocumentBody alloc] initWithDictionary:repdoc];
    if (body == nil) {
        if (error) {
            NSDictionary *userInfo =
            @{NSLocalizedDescriptionKey: NSLocalizedString(@"Data sync failed.", nil)};
            *error = [NSError errorWithDomain:CDTReplicatorFactoryErrorDomain
                                         code:CDTReplicatorFactoryErrorNilDocumentBodyForReplication
                                     userInfo:userInfo];
            NSLog(@"CDTReplicatorFactory -oneWay:error: Error. Unable to create CDTDocumentBody. "
                  @"%@\n %@.", [replication class], replication);

        }
        return nil;

    }
    
    NSError *localError = nil;
    CDTDatastoreManager *m = self.manager;
    CDTDatastore *datastore = [m datastoreNamed:kTDReplicatorDatabaseName error:&localError];
    if (localError != nil) {
        if (error) *error = localError;
        return nil;
    }
    
    CDTReplicator *replicator = [[CDTReplicator alloc] initWithReplicatorDatastore:datastore
                                                           replicationDocumentBody:body];
    
    if (replicator == nil) {
        if (error) {
            NSDictionary *userInfo =
            @{NSLocalizedDescriptionKey: NSLocalizedString(@"Data sync failed.", nil)};
            *error = [NSError errorWithDomain:CDTReplicatorFactoryErrorDomain
                                         code:CDTReplicatorFactoryErrorNilReplicatorObject
                                     userInfo:userInfo];
            NSLog(@"CDTReplicatorFactory -oneWay:error: Error. Unable to create CDTReplicator. "
                  @"%@\n %@", [replication class], replication);
        }
        return nil;
    }
    
    return replicator;

}


@end
