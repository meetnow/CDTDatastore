//
//  CSDatastoreBody.h
//  CloudantSyncIOS
//
//  Created by Michael Rhodes on 05/07/2013.
//  Copyright (c) 2013 Cloudant. All rights reserved.
//

#import <Foundation/Foundation.h>

@class TD_Body;
@class TD_Revision;

@interface CDTDocumentBody : NSObject

-(id)initWithDictionary:(NSDictionary*)dict;

@property (nonatomic,strong,readonly) TD_Body *td_body;

-(TD_Revision*)TD_RevisionValue;

@end
