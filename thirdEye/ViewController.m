//
//  ViewController.m
//  thirdEye
//
//  Created by Jon Como on 12/8/15.
//  Copyright © 2015 Jon Como. All rights reserved.
//

#import "ViewController.h"

#import <Masonry/Masonry.h>
#import <GPUImage/GPUImage.h>
#import <AFNetworking/AFNetworking.h>

#import "ip.h"

@import AVFoundation;

#define WEAK __weak typeof(self) weakSelf = self;

const CGFloat padding = 20.f;

@interface ViewController ()

@property (nonatomic, strong) GPUImageVideoCamera *camera;
// @property (nonatomic, strong) GPUImageCropFilter *crop;
@property (nonatomic, strong) GPUImageTransformFilter *transform;
@property (nonatomic, strong) GPUImageView *preview;

@property (nonatomic, strong) UILabel *output;
@property (nonatomic, strong) UIActivityIndicatorView *activity;

@property (nonatomic, strong) UISwitch *speakSwitch;
@property (nonatomic, strong) UILabel *speakLabel;

@property (nonatomic, copy) NSString *class;

@property (nonatomic, strong) AVSpeechSynthesisVoice *voice;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.camera = [[GPUImageVideoCamera alloc] initWithSessionPreset:AVCaptureSessionPreset640x480 cameraPosition:AVCaptureDevicePositionBack];
    
    self.transform = [[GPUImageTransformFilter alloc] init];
    [self.transform forceProcessingAtSize:CGSizeMake(299, 299)];
    self.transform.transform3D = CATransform3DMakeRotation(M_PI_2, 0.f, 0.f, 1.f);
    self.transform.transform3D = CATransform3DScale(self.transform.transform3D, 1.2, 1.0, 1.0);
    
    self.preview = [GPUImageView new];
    
    WEAK
    
    [self.view addSubview:self.preview];
    [self.preview mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(weakSelf.view.mas_top).offset([UIApplication sharedApplication].statusBarFrame.size.height);
        make.left.equalTo(weakSelf.view.mas_left);
        make.right.equalTo(weakSelf.view.mas_right);
        make.height.mas_equalTo(weakSelf.view.mas_width);
    }];
    
    self.output = [UILabel new];
    self.output.text = @"Tap the image to classify";
    self.output.textAlignment = NSTextAlignmentLeft;
    self.output.numberOfLines = 0;
    [self.view addSubview:self.output];
    
    [self.output mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(weakSelf.preview.mas_bottom).with.offset(padding);
        make.left.equalTo(weakSelf.view.mas_left).with.offset(padding);
        make.right.equalTo(weakSelf.view.mas_right).with.offset(-padding - 40.f);
    }];
    
    self.activity = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    [self.view addSubview:self.activity];
    [self.activity stopAnimating];
    self.activity.hidesWhenStopped = YES;
    
    [self.activity mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(weakSelf.view.mas_right).with.offset(-padding);
        make.centerY.equalTo(weakSelf.output);
    }];
    
    self.speakLabel = [UILabel new];
    self.speakLabel.text = @"Speak";
    [self.view addSubview:self.speakLabel];
    [self.speakLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(weakSelf.output.mas_bottom).with.offset(padding);
        make.left.equalTo(weakSelf.view).with.offset(padding);
    }];
    
    self.speakSwitch = [UISwitch new];
    [self.view addSubview:self.speakSwitch];
    [self.speakSwitch mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(weakSelf.speakLabel.mas_right).with.offset(padding);
        make.centerY.equalTo(weakSelf.speakLabel);
    }];
    
    
    [self.camera addTarget:self.transform];
    [self.transform addTarget:self.preview];
    [self.camera startCameraCapture];
    
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapped)];
    [self.preview addGestureRecognizer:tap];
    
    UITapGestureRecognizer *tapSpeak = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(speakAgain)];
    [self.speakLabel addGestureRecognizer:tapSpeak];
    
    self.voice = [AVSpeechSynthesisVoice voiceWithLanguage:@"en-US"];
    
    
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
        [weakSelf.camera stopCameraCapture];
    }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
        [weakSelf.camera startCameraCapture];
    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)speakAgain {
    [self speak:self.class];
}

- (void)tapped {
    // Snap a pic
    [self.transform useNextFrameForImageCapture];
    UIImage *image = [self.transform imageFromCurrentFramebuffer];
    
    NSData *data = UIImageJPEGRepresentation(image, .9);
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:SERVER_URL]];
    [request setHTTPBody:data];
    [request setHTTPMethod:@"POST"];
    
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    AFURLSessionManager *manager = [[AFURLSessionManager alloc] initWithSessionConfiguration:configuration];
    
    [self.activity startAnimating];
    self.class = @"";
    self.output.text = @"Classifying, one moment";
    
    WEAK
    NSURLSessionDataTask *dataTask = [manager dataTaskWithRequest:request completionHandler:^(NSURLResponse *response, id responseObject, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.activity stopAnimating];
            
            if (error) {
                NSLog(@"Error: %@", error);
                weakSelf.output.text = error.description;
            } else {
                NSLog(@"%@ %@", response, responseObject);
                NSLog(@"GOT %@", responseObject);
                
                if ([responseObject isKindOfClass:[NSDictionary class]]) {
                    NSDictionary *dict = responseObject;
                    
                    weakSelf.class = dict[@"class"];
                    weakSelf.output.text = weakSelf.class;
                    if (weakSelf.speakSwitch.isOn) {
                        [weakSelf speak:weakSelf.class];
                    }
                }
            }
        });
    }];
    [dataTask resume];
}

- (void)speak:(NSString *)text {
    AVSpeechUtterance *utterance = [[AVSpeechUtterance alloc] initWithString:text];
    utterance.voice = self.voice;
    
    AVSpeechSynthesizer *synthesizer = [[AVSpeechSynthesizer alloc] init];
    [synthesizer speakUtterance:utterance];
}

@end
