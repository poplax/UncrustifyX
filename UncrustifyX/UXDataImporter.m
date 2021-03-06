//
//  UXDataImporter.m
//  UncrustifyX
//
//  Created by Ryan Maxwell on 13/10/12.
//  Copyright (c) 2012 Ryan Maxwell. All rights reserved.
//

#import "UXDataImporter.h"

#import "UXLanguage.h"
#import "UXCategory.h"
#import "UXSubcategory.h"
#import "UXOption.h"
#import "UXValueType.h"
#import "UXValue.h"
#import "UXCodeSample.h"

@implementation UXDataImporter

+ (void)deleteData {
    [UXCategory truncateAll];
    [UXSubcategory truncateAll];
    [UXLanguage truncateAll];
    [UXOption truncateAll];
    [UXValueType truncateAll];
    [UXCodeSample truncateAll];
    [NSManagedObjectContext.defaultContext saveToPersistentStoreAndWait];
}

+ (NSDictionary *)definitionsDictionary {
    NSURL *fileURL = [NSBundle.mainBundle URLForResource:@"Definitions" withExtension:@"plist"];
    return [NSDictionary dictionaryWithContentsOfURL:fileURL];
}

+ (void)importDefinitions {
    NSDictionary *rootDict = [self definitionsDictionary];
    
    /* Check updated at date */
    NSDate *definitionsUpdatedAt = rootDict[@"UpdatedAt"];
    if ([definitionsUpdatedAt timeIntervalSinceDate:UXDEFAULTS.definitionsUpdatedAt] == 0) {
        
        DLog(@"Current definitions up to date");
        return;
    };
    
    /* reimport data */
    DLog(@"Definitions version (%@) newer than current definitions (%@) - Performing Import",
         definitionsUpdatedAt,
         UXDEFAULTS.definitionsUpdatedAt);
    
    UXDEFAULTS.definitionsUpdatedAt = definitionsUpdatedAt;
    
    NSMutableDictionary *languagesDict = NSMutableDictionary.dictionary;
    NSMutableDictionary *categoriesDict = NSMutableDictionary.dictionary;
    NSMutableDictionary *subcategoriesDict = NSMutableDictionary.dictionary;
    NSMutableDictionary *valueTypesDict = NSMutableDictionary.dictionary;
    
    /* Create or Update Languages */
    NSDictionary *languages = rootDict[@"Languages"];
    [languages enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop){
        if ([value isKindOfClass:NSDictionary.class]) {
            NSDictionary *language = (NSDictionary *)value;
            
            UXLanguage *languageEntity = [UXLanguage findFirstByAttribute:UXLanguageAttributes.code
                                                                withValue:key];
            if (!languageEntity) {
                languageEntity = [UXLanguage createEntity];
                languageEntity.code = key;
                languageEntity.includedInDocumentation = YES;
            }
            
            languageEntity.name = language[@"Name"];

            /* Replace all Extensions */
            NSArray *extensions = language[@"Extensions"];
            NSMutableString *extensionsString = NSMutableString.string;
            if (extensions && extensions.count) {
                [extensions enumerateObjectsUsingBlock:^(NSString *extension, NSUInteger index, BOOL *stop){
                    [extensionsString appendString:extension];
                    if (index != extensions.count -1) {
                        [extensionsString appendString:UXLanguageExtensionDelimiter];
                    }
                }];
            }
            languageEntity.extensions = extensionsString;
            
            languagesDict[key] = languageEntity;
        }
    }];
    
    /* Replace all Value Types */
    [UXValueType truncateAll];
    for (NSDictionary *valueType in rootDict[@"ValueTypes"]) {
        NSString *theType = valueType[@"Type"];
        
        UXValueType *valueTypeEntity = [UXValueType createEntity];
        valueTypeEntity.type = theType;
        
        for (NSString *value in valueType[@"Values"]) {
            UXValue *newValue = [UXValue createEntity];
            newValue.value = value;
            newValue.valueType = valueTypeEntity;
        }

        NSNumber *valueTypeID = valueType[@"ID"];
        if (valueTypeID) {
            valueTypesDict[valueTypeID] = valueTypeEntity;
        }
    }
    
    /* Replace all code samples */
    [UXCodeSample truncateAll];
    for (NSDictionary *codeSample in rootDict[@"CodeSamples"]) {
        UXCodeSample *newCodeSample = [UXCodeSample createEntity];
        newCodeSample.codeSampleDescription = codeSample[@"Description"];
        
        NSString *languageCode = codeSample[@"Language"];
        if (languageCode) {
            newCodeSample.language = languagesDict[languageCode];
        }
        newCodeSample.source = codeSample[@"Source"];
    }
    
    /* Create or Update Options */
    NSDictionary *options = rootDict[@"Options"];
    [options enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop){
        if ([value isKindOfClass:NSDictionary.class]) {
            NSDictionary *option = (NSDictionary *)value;
            
            UXOption *optionEntity = [UXOption findFirstByAttribute:UXOptionAttributes.code
                                                          withValue:key];
            if (!optionEntity) {
                optionEntity = [UXOption createEntity];
                optionEntity.code = key;
            }
            
            optionEntity.name = option[@"Name"];
            optionEntity.optionDescription = option[@"Description"];
            
            NSString *categoryName = option[@"Category"];
            UXCategory *categoryEntity = nil;
            if (categoryName.length) {
                categoryEntity = categoriesDict[categoryName];
                if (!categoryEntity) {
                    categoryEntity = [UXCategory findFirstByAttribute:UXAbstractCategoryAttributes.name
                                                            withValue:categoryName];
                    if (!categoryEntity) {
                        categoryEntity = [UXCategory createEntity];
                        categoryEntity.name = categoryName;
                    }
                    
                    categoriesDict[categoryName] = categoryEntity;
                }
                optionEntity.category = categoryEntity;
            } else {
                optionEntity.category =
                categoryEntity = UXCategory.otherCategory;
            }
            
            NSString *subcategoryName = option[@"Subcategory"];
            UXSubcategory *subcategoryEntity = nil;
            if (subcategoryName.length) {
                subcategoryEntity = subcategoriesDict[subcategoryName];
                if (!subcategoryEntity) {
                    subcategoryEntity = [UXSubcategory findFirstByAttribute:UXAbstractCategoryAttributes.name
                                                                  withValue:subcategoryName];
                    if (!subcategoryEntity) {
                        subcategoryEntity = [UXSubcategory createEntity];
                        subcategoryEntity.name = subcategoryName;
                    } else {
                        /* relink parent categories */
                        subcategoryEntity.parentCategories = nil;
                    }
                    
                    subcategoriesDict[subcategoryName] = subcategoryEntity;
                }
                
                optionEntity.subcategory = subcategoryEntity;
            } else {
                optionEntity.subcategory = subcategoryEntity = UXSubcategory.otherSubcategory;
            }
            [subcategoryEntity addParentCategoriesObject:categoryEntity];
            
            /* Relink Value Types */
            optionEntity.valueType = nil;
            NSNumber *valueTypeID = option[@"ValueTypeID"];
            if (valueTypeID) {
                optionEntity.valueType = valueTypesDict[valueTypeID];
            }
            
            optionEntity.defaultValue = option[@"Default"];
            
            /* Relink Languages */
            optionEntity.languages = nil;
            for (NSString *languageCode in option[@"Languages"]) {
                UXLanguage *language = languagesDict[languageCode];
                if (language) {
                    [optionEntity addLanguagesObject:language];
                }
            }
        }
    }];
    
    /* Remove empty categories/subcategories */
    NSPredicate *emptyCategoriesPredicate = [NSPredicate predicateWithFormat:@"%K.@count == 0", UXCategoryRelationships.options];
    NSArray *emptyCategories = [UXCategory findAllWithPredicate:emptyCategoriesPredicate];
    
    for (UXCategory *category in emptyCategories) {
        [category deleteEntity];
    }
    
    NSArray *emptySubcategories = [UXSubcategory findAllWithPredicate:emptyCategoriesPredicate];
    
    for (UXSubcategory *subcategory in emptySubcategories) {
        [subcategory deleteEntity];
    }
    
    
    [NSManagedObjectContext.defaultContext saveToPersistentStoreAndWait];
}

@end
