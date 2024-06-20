//
//  VKFullscreenContainer.h
//  VideoKitSample
//
//  Created by Murat Sudan on 14/04/16.
//  Copyright © 2016 iosvideokit. All rights reserved.
//

#import <UIKit/UIKit.h>

@class VKPlayerControllerBase;

/**
 *  VKFullScreenContainer is a container that helps VKPlayerController object play in fullscreen mode.
 *
 */
@interface VKFullscreenContainer : UIViewController {
    VKPlayerControllerBase *_playerController;
    UIView *_superviewBefore;
    CGRect _rectBefore;
    CGRect _rectWin;
    UIViewAutoresizing _autoresizingMaskBefore;
}

/**
 *  Initialize VKFullScreenPlayer object
 *
 *  @param player Needs VKPlayerControllerBase object to holds initial states of player
 *  @param rect Needs CGRect as a starting frame to begin fullscreen animation 
 */
- (id)initWithPlayerController:(VKPlayerControllerBase *)player windowRect:(CGRect)rect;

/**
 *  Dismiss container ViewController
 *
 *  @param animated Controls the dismiss animation
 */
- (void)dismissContainerWithAnimated:(BOOL)animated completionHandler:(void (^)(void))completionHandler;

///A control property to enable/disable fix for animation glitch only happens in iPhoneX device. It's effective only on iPhoneX devices Default is NO
@property(nonatomic, assign) BOOL disableiPhoneXFullScreenToEmbedAnimationBugFix;

@end
