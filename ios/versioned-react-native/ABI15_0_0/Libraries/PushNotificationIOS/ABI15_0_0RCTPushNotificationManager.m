/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ABI15_0_0RCTPushNotificationManager.h"

#import <ReactABI15_0_0/ABI15_0_0RCTBridge.h>
#import <ReactABI15_0_0/ABI15_0_0RCTConvert.h>
#import <ReactABI15_0_0/ABI15_0_0RCTEventDispatcher.h>
#import <ReactABI15_0_0/ABI15_0_0RCTUtils.h>

NSString *const ABI15_0_0RCTLocalNotificationReceived = @"LocalNotificationReceived";
NSString *const ABI15_0_0RCTRemoteNotificationReceived = @"RemoteNotificationReceived";
NSString *const ABI15_0_0RCTRemoteNotificationsRegistered = @"RemoteNotificationsRegistered";
NSString *const ABI15_0_0RCTRegisterUserNotificationSettings = @"RegisterUserNotificationSettings";

NSString *const ABI15_0_0RCTErrorUnableToRequestPermissions = @"E_UNABLE_TO_REQUEST_PERMISSIONS";
NSString *const ABI15_0_0RCTErrorRemoteNotificationRegistrationFailed = @"E_FAILED_TO_REGISTER_FOR_REMOTE_NOTIFICATIONS";

#if !TARGET_OS_TV
@implementation ABI15_0_0RCTConvert (NSCalendarUnit)

ABI15_0_0RCT_ENUM_CONVERTER(NSCalendarUnit,
                   (@{
                      @"year": @(NSCalendarUnitYear),
                      @"month": @(NSCalendarUnitMonth),
                      @"week": @(NSCalendarUnitWeekOfYear),
                      @"day": @(NSCalendarUnitDay),
                      @"hour": @(NSCalendarUnitHour),
                      @"minute": @(NSCalendarUnitMinute)
                      }),
                   0,
                   integerValue)

@end

@interface ABI15_0_0RCTPushNotificationManager ()
@property (nonatomic, strong) NSMutableDictionary *remoteNotificationCallbacks;
@end

@implementation ABI15_0_0RCTConvert (UILocalNotification)

+ (UILocalNotification *)UILocalNotification:(id)json
{
  NSDictionary<NSString *, id> *details = [self NSDictionary:json];
  UILocalNotification *notification = [UILocalNotification new];
  notification.fireDate = [ABI15_0_0RCTConvert NSDate:details[@"fireDate"]] ?: [NSDate date];
  notification.alertBody = [ABI15_0_0RCTConvert NSString:details[@"alertBody"]];
  notification.alertAction = [ABI15_0_0RCTConvert NSString:details[@"alertAction"]];
  notification.soundName = [ABI15_0_0RCTConvert NSString:details[@"soundName"]] ?: UILocalNotificationDefaultSoundName;
  notification.userInfo = [ABI15_0_0RCTConvert NSDictionary:details[@"userInfo"]];
  notification.category = [ABI15_0_0RCTConvert NSString:details[@"category"]];
  notification.repeatInterval = [ABI15_0_0RCTConvert NSCalendarUnit:details[@"repeatInterval"]];
  if (details[@"applicationIconBadgeNumber"]) {
    notification.applicationIconBadgeNumber = [ABI15_0_0RCTConvert NSInteger:details[@"applicationIconBadgeNumber"]];
  }
  return notification;
}

ABI15_0_0RCT_ENUM_CONVERTER(UIBackgroundFetchResult, (@{
  @"UIBackgroundFetchResultNewData": @(UIBackgroundFetchResultNewData),
  @"UIBackgroundFetchResultNoData": @(UIBackgroundFetchResultNoData),
  @"UIBackgroundFetchResultFailed": @(UIBackgroundFetchResultFailed),
}), UIBackgroundFetchResultNoData, integerValue)

@end
#endif //TARGET_OS_TV

@implementation ABI15_0_0RCTPushNotificationManager
{
  ABI15_0_0RCTPromiseResolveBlock _requestPermissionsResolveBlock;
}

#if !TARGET_OS_TV

static NSDictionary *ABI15_0_0RCTFormatLocalNotification(UILocalNotification *notification)
{
  NSMutableDictionary *formattedLocalNotification = [NSMutableDictionary dictionary];
  if (notification.fireDate) {
    NSDateFormatter *formatter = [NSDateFormatter new];
    [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"];
    NSString *fireDateString = [formatter stringFromDate:notification.fireDate];
    formattedLocalNotification[@"fireDate"] = fireDateString;
  }
  formattedLocalNotification[@"alertAction"] = ABI15_0_0RCTNullIfNil(notification.alertAction);
  formattedLocalNotification[@"alertBody"] = ABI15_0_0RCTNullIfNil(notification.alertBody);
  formattedLocalNotification[@"applicationIconBadgeNumber"] = @(notification.applicationIconBadgeNumber);
  formattedLocalNotification[@"category"] = ABI15_0_0RCTNullIfNil(notification.category);
  formattedLocalNotification[@"soundName"] = ABI15_0_0RCTNullIfNil(notification.soundName);
  formattedLocalNotification[@"userInfo"] = ABI15_0_0RCTNullIfNil(ABI15_0_0RCTJSONClean(notification.userInfo));
  formattedLocalNotification[@"remote"] = @NO;
  return formattedLocalNotification;
}

#endif //TARGET_OS_TV

ABI15_0_0RCT_EXPORT_MODULE()

- (dispatch_queue_t)methodQueue
{
  return dispatch_get_main_queue();
}

- (void)startObserving
{
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(handleLocalNotificationReceived:)
                                               name:ABI15_0_0RCTLocalNotificationReceived
                                             object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(handleRemoteNotificationReceived:)
                                               name:ABI15_0_0RCTRemoteNotificationReceived
                                             object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(handleRemoteNotificationsRegistered:)
                                               name:ABI15_0_0RCTRemoteNotificationsRegistered
                                             object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(handleRemoteNotificationRegistrationError:)
                                               name:ABI15_0_0RCTErrorRemoteNotificationRegistrationFailed
                                             object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(handleRegisterUserNotificationSettings:)
                                               name:ABI15_0_0RCTRegisterUserNotificationSettings
                                             object:nil];
}

- (void)stopObserving
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSArray<NSString *> *)supportedEvents
{
  return @[@"localNotificationReceived",
           @"remoteNotificationReceived",
           @"remoteNotificationsRegistered",
           @"remoteNotificationRegistrationError"];
}

#if !TARGET_OS_TV

+ (void)didRegisterUserNotificationSettings:(__unused UIUserNotificationSettings *)notificationSettings
{
  if ([UIApplication instancesRespondToSelector:@selector(registerForRemoteNotifications)]) {
    [[UIApplication sharedApplication] registerForRemoteNotifications];
    [[NSNotificationCenter defaultCenter] postNotificationName:ABI15_0_0RCTRegisterUserNotificationSettings
                                                        object:self
                                                      userInfo:@{@"notificationSettings": notificationSettings}];
  }
}

+ (void)didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
  NSMutableString *hexString = [NSMutableString string];
  NSUInteger deviceTokenLength = deviceToken.length;
  const unsigned char *bytes = deviceToken.bytes;
  for (NSUInteger i = 0; i < deviceTokenLength; i++) {
    [hexString appendFormat:@"%02x", bytes[i]];
  }
  [[NSNotificationCenter defaultCenter] postNotificationName:ABI15_0_0RCTRemoteNotificationsRegistered
                                                      object:self
                                                    userInfo:@{@"deviceToken" : [hexString copy]}];
}

+ (void)didFailToRegisterForRemoteNotificationsWithError:(NSError *)error
{
  [[NSNotificationCenter defaultCenter] postNotificationName:ABI15_0_0RCTErrorRemoteNotificationRegistrationFailed
                                                      object:self
                                                    userInfo:@{@"error": error}];
}

+ (void)didReceiveRemoteNotification:(NSDictionary *)notification
{
  NSDictionary *userInfo = @{@"notification": notification};
  [[NSNotificationCenter defaultCenter] postNotificationName:ABI15_0_0RCTRemoteNotificationReceived
                                                      object:self
                                                    userInfo:userInfo];
}

+ (void)didReceiveRemoteNotification:(NSDictionary *)notification
              fetchCompletionHandler:(ABI15_0_0RCTRemoteNotificationCallback)completionHandler
{
  NSDictionary *userInfo = @{@"notification": notification, @"completionHandler": completionHandler};
  [[NSNotificationCenter defaultCenter] postNotificationName:ABI15_0_0RCTRemoteNotificationReceived
                                                      object:self
                                                    userInfo:userInfo];
}

+ (void)didReceiveLocalNotification:(UILocalNotification *)notification
{
  [[NSNotificationCenter defaultCenter] postNotificationName:ABI15_0_0RCTLocalNotificationReceived
                                                      object:self
                                                    userInfo:ABI15_0_0RCTFormatLocalNotification(notification)];
}

- (void)handleLocalNotificationReceived:(NSNotification *)notification
{
  [self sendEventWithName:@"localNotificationReceived" body:notification.userInfo];
}

- (void)handleRemoteNotificationReceived:(NSNotification *)notification
{
  NSMutableDictionary *remoteNotification = [NSMutableDictionary dictionaryWithDictionary:notification.userInfo[@"notification"]];
  ABI15_0_0RCTRemoteNotificationCallback completionHandler = notification.userInfo[@"completionHandler"];
  NSString *notificationId = [[NSUUID UUID] UUIDString];
  remoteNotification[@"notificationId"] = notificationId;
  remoteNotification[@"remote"] = @YES;
  if (completionHandler) {
    if (!self.remoteNotificationCallbacks) {
      // Lazy initialization
      self.remoteNotificationCallbacks = [NSMutableDictionary dictionary];
    }
    self.remoteNotificationCallbacks[notificationId] = completionHandler;
  }

  [self sendEventWithName:@"remoteNotificationReceived" body:remoteNotification];
}

- (void)handleRemoteNotificationsRegistered:(NSNotification *)notification
{
  [self sendEventWithName:@"remoteNotificationsRegistered" body:notification.userInfo];
}

- (void)handleRemoteNotificationRegistrationError:(NSNotification *)notification
{
  NSError *error = notification.userInfo[@"error"];
  NSDictionary *errorDetails = @{
    @"message": error.localizedDescription,
    @"code": @(error.code),
    @"details": error.userInfo,
  };
  [self sendEventWithName:@"remoteNotificationRegistrationError" body:errorDetails];
}

- (void)handleRegisterUserNotificationSettings:(NSNotification *)notification
{
  if (_requestPermissionsResolveBlock == nil) {
    return;
  }

  UIUserNotificationSettings *notificationSettings = notification.userInfo[@"notificationSettings"];
  NSDictionary *notificationTypes = @{
    @"alert": @((notificationSettings.types & UIUserNotificationTypeAlert) > 0),
    @"sound": @((notificationSettings.types & UIUserNotificationTypeSound) > 0),
    @"badge": @((notificationSettings.types & UIUserNotificationTypeBadge) > 0),
  };

  _requestPermissionsResolveBlock(notificationTypes);
  _requestPermissionsResolveBlock = nil;
}

ABI15_0_0RCT_EXPORT_METHOD(onFinishRemoteNotification:(NSString *)notificationId fetchResult:(UIBackgroundFetchResult)result) {
  ABI15_0_0RCTRemoteNotificationCallback completionHandler = self.remoteNotificationCallbacks[notificationId];
  if (!completionHandler) {
    ABI15_0_0RCTLogError(@"There is no completion handler with notification id: %@", notificationId);
    return;
  }
  completionHandler(result);
  [self.remoteNotificationCallbacks removeObjectForKey:notificationId];
}

/**
 * Update the application icon badge number on the home screen
 */
ABI15_0_0RCT_EXPORT_METHOD(setApplicationIconBadgeNumber:(NSInteger)number)
{
  ABI15_0_0RCTSharedApplication().applicationIconBadgeNumber = number;
}

/**
 * Get the current application icon badge number on the home screen
 */
ABI15_0_0RCT_EXPORT_METHOD(getApplicationIconBadgeNumber:(ABI15_0_0RCTResponseSenderBlock)callback)
{
  callback(@[@(ABI15_0_0RCTSharedApplication().applicationIconBadgeNumber)]);
}

ABI15_0_0RCT_EXPORT_METHOD(requestPermissions:(NSDictionary *)permissions
                 resolver:(ABI15_0_0RCTPromiseResolveBlock)resolve
                 rejecter:(ABI15_0_0RCTPromiseRejectBlock)reject)
{
  if (ABI15_0_0RCTRunningInAppExtension()) {
    reject(ABI15_0_0RCTErrorUnableToRequestPermissions, nil, ABI15_0_0RCTErrorWithMessage(@"Requesting push notifications is currently unavailable in an app extension"));
    return;
  }

  if (_requestPermissionsResolveBlock != nil) {
    ABI15_0_0RCTLogError(@"Cannot call requestPermissions twice before the first has returned.");
    return;
  }

  _requestPermissionsResolveBlock = resolve;

  UIUserNotificationType types = UIUserNotificationTypeNone;
  if (permissions) {
    if ([ABI15_0_0RCTConvert BOOL:permissions[@"alert"]]) {
      types |= UIUserNotificationTypeAlert;
    }
    if ([ABI15_0_0RCTConvert BOOL:permissions[@"badge"]]) {
      types |= UIUserNotificationTypeBadge;
    }
    if ([ABI15_0_0RCTConvert BOOL:permissions[@"sound"]]) {
      types |= UIUserNotificationTypeSound;
    }
  } else {
    types = UIUserNotificationTypeAlert | UIUserNotificationTypeBadge | UIUserNotificationTypeSound;
  }

  UIApplication *app = ABI15_0_0RCTSharedApplication();
  if ([app respondsToSelector:@selector(registerUserNotificationSettings:)]) {
    UIUserNotificationSettings *notificationSettings =
      [UIUserNotificationSettings settingsForTypes:(NSUInteger)types categories:nil];
    [app registerUserNotificationSettings:notificationSettings];
  } else {
    [app registerForRemoteNotificationTypes:(NSUInteger)types];
  }
}

ABI15_0_0RCT_EXPORT_METHOD(abandonPermissions)
{
  [ABI15_0_0RCTSharedApplication() unregisterForRemoteNotifications];
}

ABI15_0_0RCT_EXPORT_METHOD(checkPermissions:(ABI15_0_0RCTResponseSenderBlock)callback)
{
  if (ABI15_0_0RCTRunningInAppExtension()) {
    callback(@[@{@"alert": @NO, @"badge": @NO, @"sound": @NO}]);
    return;
  }

  NSUInteger types = [ABI15_0_0RCTSharedApplication() currentUserNotificationSettings].types;
  callback(@[@{
    @"alert": @((types & UIUserNotificationTypeAlert) > 0),
    @"badge": @((types & UIUserNotificationTypeBadge) > 0),
    @"sound": @((types & UIUserNotificationTypeSound) > 0),
  }]);
}

ABI15_0_0RCT_EXPORT_METHOD(presentLocalNotification:(UILocalNotification *)notification)
{
  [ABI15_0_0RCTSharedApplication() presentLocalNotificationNow:notification];
}

ABI15_0_0RCT_EXPORT_METHOD(scheduleLocalNotification:(UILocalNotification *)notification)
{
  [ABI15_0_0RCTSharedApplication() scheduleLocalNotification:notification];
}

ABI15_0_0RCT_EXPORT_METHOD(cancelAllLocalNotifications)
{
  [ABI15_0_0RCTSharedApplication() cancelAllLocalNotifications];
}

ABI15_0_0RCT_EXPORT_METHOD(cancelLocalNotifications:(NSDictionary<NSString *, id> *)userInfo)
{
  for (UILocalNotification *notification in [UIApplication sharedApplication].scheduledLocalNotifications) {
    __block BOOL matchesAll = YES;
    NSDictionary<NSString *, id> *notificationInfo = notification.userInfo;
    // Note: we do this with a loop instead of just `isEqualToDictionary:`
    // because we only require that all specified userInfo values match the
    // notificationInfo values - notificationInfo may contain additional values
    // which we don't care about.
    [userInfo enumerateKeysAndObjectsUsingBlock:^(NSString *key, id obj, BOOL *stop) {
      if (![notificationInfo[key] isEqual:obj]) {
        matchesAll = NO;
        *stop = YES;
      }
    }];
    if (matchesAll) {
      [[UIApplication sharedApplication] cancelLocalNotification:notification];
    }
  }
}

ABI15_0_0RCT_EXPORT_METHOD(getInitialNotification:(ABI15_0_0RCTPromiseResolveBlock)resolve
                  reject:(__unused ABI15_0_0RCTPromiseRejectBlock)reject)
{
  NSMutableDictionary<NSString *, id> *initialNotification =
    [self.bridge.launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey] mutableCopy];

  UILocalNotification *initialLocalNotification =
    self.bridge.launchOptions[UIApplicationLaunchOptionsLocalNotificationKey];

  if (initialNotification) {
    initialNotification[@"remote"] = @YES;
    resolve(initialNotification);
  } else if (initialLocalNotification) {
    resolve(ABI15_0_0RCTFormatLocalNotification(initialLocalNotification));
  } else {
    resolve((id)kCFNull);
  }
}

ABI15_0_0RCT_EXPORT_METHOD(getScheduledLocalNotifications:(ABI15_0_0RCTResponseSenderBlock)callback)
{
  NSArray<UILocalNotification *> *scheduledLocalNotifications = [UIApplication sharedApplication].scheduledLocalNotifications;
  NSMutableArray<NSDictionary *> *formattedScheduledLocalNotifications = [NSMutableArray new];
  for (UILocalNotification *notification in scheduledLocalNotifications) {
    [formattedScheduledLocalNotifications addObject:ABI15_0_0RCTFormatLocalNotification(notification)];
  }
  callback(@[formattedScheduledLocalNotifications]);
}

#endif //TARGET_OS_TV

@end
