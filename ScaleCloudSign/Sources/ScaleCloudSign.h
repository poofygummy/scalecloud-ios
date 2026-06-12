//
//  ScaleCloudSign.h
//  ScaleCloudSign
//
//  Umbrella header exposing Objective-C to Swift within the framework
//

#import <Foundation/Foundation.h>

// Roxas - Generic
#import "Roxas/RSTDefines.h"
#import "Roxas/RSTConstants.h"
#import "Roxas/RSTHelperFile.h"
#import "Roxas/RSTError.h"

// Roxas - Operations
#import "Roxas/RSTOperationQueue.h"
#import "Roxas/RSTOperation.h"
#import "Roxas/RSTOperation_Subclasses.h"
#import "Roxas/RSTBlockOperation.h"
#import "Roxas/RSTLoadOperation.h"

// Roxas - Core Data
#import "Roxas/RSTPersistentContainer.h"
#import "Roxas/RSTRelationshipPreservingMergePolicy.h"

// Roxas - Cell Content
#import "Roxas/RSTCellContentCell.h"
#import "Roxas/RSTCellContentView.h"
#import "Roxas/RSTCellContentChange.h"
#import "Roxas/RSTCellContentChangeOperation.h"
#import "Roxas/RSTCellContentPrefetchingDataSource.h"
#import "Roxas/RSTCellContentDataSource.h"
#import "Roxas/RSTArrayDataSource.h"
#import "Roxas/RSTFetchedResultsDataSource.h"
#import "Roxas/RSTDynamicDataSource.h"
#import "Roxas/RSTCompositeDataSource.h"
#import "Roxas/RSTSearchController.h"
#import "Roxas/RSTCollectionViewGridLayout.h"
#import "Roxas/RSTCollectionViewCell.h"

// Roxas - Visual Components
#import "Roxas/RSTPlaceholderView.h"
#import "Roxas/RSTLaunchViewController.h"
#import "Roxas/RSTSeparatorView.h"
#import "Roxas/RSTNibView.h"
#import "Roxas/RSTTintedImageView.h"
#import "Roxas/RSTToastView.h"
#import "Roxas/RSTNavigationController.h"

// Roxas - Functionality
#import "Roxas/RSTHasher.h"

// Roxas - Categories
#import "Roxas/UIImage+Manipulation.h"
#import "Roxas/NSBundle+Extensions.h"
#import "Roxas/NSFileManager+URLs.h"
#import "Roxas/NSUserDefaults+DynamicProperties.h"
#import "Roxas/UIViewController+TransitionState.h"
#import "Roxas/UIView+AnimatedHide.h"
#import "Roxas/NSString+Localization.h"
#import "Roxas/NSPredicate+Search.h"
#import "Roxas/UIAlertAction+Actions.h"
#import "Roxas/NSLayoutConstraint+Edges.h"
#import "Roxas/NSConstraintConflict+Conveniences.h"
#import "Roxas/UISpringTimingParameters+Conveniences.h"
#import "Roxas/RSTActivityIndicating.h"
#import "Roxas/UIKit+ActivityIndicating.h"
#import "Roxas/UITableView+CellContent.h"
#import "Roxas/UITableViewCell+CellContent.h"
#import "Roxas/UICollectionView+CellContent.h"
#import "Roxas/UICollectionViewCell+CellContent.h"

// AltStoreCore
#import "AltStoreCore/Types/ALTAppPermissions.h"
#import "AltStoreCore/Types/ALTSourceUserInfoKey.h"
#import "AltStoreCore/Types/ALTPatreonBenefitID.h"
#import "AltStoreCore/Shared/ALTConstants.h"
#import "AltStoreCore/Shared/Connections/ALTConnection.h"
#import "AltStoreCore/Shared/Errors/ALTWrappedError.h"
#import "AltStoreCore/Shared/Categories/NSError+ALTServerError.h"
#import "AltStoreCore/Shared/Categories/CFNotificationName+AltStore.h"

// AltSign - Apple API
#import "AltSign/AppleAPI/ALTAppleAPI.h"
#import "AltSign/AppleAPI/ALTAppleAPISession.h"

// AltSign - Signing
#import "AltSign/Signing/ALTSigner.h"

// AltSign - Model
#import "AltSign/Model/ALTApplication.h"
#import "AltSign/Model/AppleAPI/ALTAccount.h"
#import "AltSign/Model/AppleAPI/ALTAnisetteData.h"
#import "AltSign/Model/AppleAPI/ALTTeam.h"
#import "AltSign/Model/AppleAPI/ALTDevice.h"
#import "AltSign/Model/AppleAPI/ALTCertificate.h"
#import "AltSign/Model/AppleAPI/ALTAppID.h"
#import "AltSign/Model/AppleAPI/ALTAppGroup.h"
#import "AltSign/Model/AppleAPI/ALTProvisioningProfile.h"

// AltSign - Categories
#import "AltSign/Categories/NSError+ALTErrors.h"
#import "AltSign/Categories/NSFileManager+Zip.h"
#import "AltSign/Categories/NSCharacterSet+ASCII.h"

// AltSign - Capabilities
#import "AltSign/Capabilities/ALTCapabilities.h"
