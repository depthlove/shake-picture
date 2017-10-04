//
//  ViewController.m
//  shake-picture
//
//  Created by suntongmian on 2017/10/4.
//  Copyright © 2017年 Pili Engineering, Qiniu Inc. All rights reserved.
//

#import "ViewController.h"
#import "CameraViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    UIButton *recordButton = [UIButton buttonWithType:UIButtonTypeCustom];
    recordButton.frame = CGRectMake(0, 0, 62, 62);
    recordButton.center = CGPointMake(CGRectGetWidth([UIScreen mainScreen].bounds) / 2, CGRectGetHeight([UIScreen mainScreen].bounds) / 2);
    recordButton.backgroundColor = [UIColor redColor];
    recordButton.layer.cornerRadius = 31;
    recordButton.layer.borderWidth = 2;
    recordButton.layer.borderColor = [UIColor grayColor].CGColor;
    [self.view addSubview:recordButton];
    [recordButton addTarget:self action:@selector(pressRecordButton:) forControlEvents:UIControlEventTouchUpInside];
    
    UILabel *recordLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 100, 44)];
    recordLabel.text = @"OpenGL渲染";
    recordLabel.textAlignment = NSTextAlignmentCenter;
    recordLabel.textColor = [UIColor grayColor];
    recordLabel.center = CGPointMake(recordButton.center.x, recordButton.center.y + 44);
    [self.view addSubview:recordLabel];
}

- (void)pressRecordButton:(id)sender {
    CameraViewController *cameraViewController = [[CameraViewController alloc] init];
    [self presentViewController:cameraViewController animated:YES completion:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
