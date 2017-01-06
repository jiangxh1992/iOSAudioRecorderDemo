//
//  ViewController.m
//  IOSRecorderDemo
//
//  Created by Xinhou Jiang on 29/12/16.
//  Copyright © 2016年 Xinhou Jiang. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>

// 文件名
#define fileName_caf @"demoRecord.caf"

@interface ViewController () // 录音和播放器的代理选择性添加：<AVAudioRecorderDelegate,AVAudioPlayerDelegate>

// 录音文件绝对路径
@property (nonatomic, copy) NSString *filepathCaf;
// 录音机对象
@property (nonatomic, strong) AVAudioRecorder *audioRecorder;
// 播放器对象，和上一章音频播放的方法相同，只不过这里简单播放即可
@property (nonatomic, strong) AVAudioPlayer *audioPlayer;
// 用一个processview显示声波波动情况
@property (nonatomic, weak) IBOutlet UIProgressView *processView;
// 用一个label显示录制时间
@property (nonatomic, weak) IBOutlet UILabel *recordTime;
// UI刷新监听器
@property (nonatomic, strong) NSTimer *timer;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // 初始化工作
    [self initData];
}

// 初始化
- (void)initData {
    // 获取沙盒Document文件路径
    NSString *sandBoxPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    // 拼接录音文件绝对路径
    _filepathCaf = [sandBoxPath stringByAppendingPathComponent:fileName_caf];
    
    // 1.创建音频会话
    AVAudioSession *audioSession=[AVAudioSession sharedInstance];
    // 设置录音类别（这里选用录音后可回放录音类型）
    [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    [audioSession setActive:YES error:nil];
    
    // 2.开启定时器
    _timer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(update) userInfo:nil repeats:YES];
}

#pragma mark -录音设置工具函数
// 懒加载录音机对象get方法
- (AVAudioRecorder *)audioRecorder {
    if (!_audioRecorder) {
        // 保存录音文件的路径url
        NSURL *url = [NSURL URLWithString:_filepathCaf];
        // 创建录音格式设置setting
        NSDictionary *setting = [self getAudioSetting];
        // error
        NSError *error=nil;
        
        _audioRecorder = [[AVAudioRecorder alloc]initWithURL:url settings:setting error:&error];
        _audioRecorder.meteringEnabled = YES;// 监控声波
        if (error) {
            NSLog(@"创建录音机对象时发生错误，错误信息：%@",error.localizedDescription);
            return nil;
        }
    }
    return _audioRecorder;
}

// audioPlayer懒加载getter方法
- (AVAudioPlayer *)audioPlayer {
    _audioRecorder = NULL; // 每次都创建新的播放器，删除旧的
    
    // 资源路径
    NSURL *url = [NSURL fileURLWithPath:_filepathCaf];
    
    // 初始化播放器，注意这里的Url参数只能为本地文件路径，不支持HTTP Url
    NSError *error = nil;
    _audioPlayer = [[AVAudioPlayer alloc]initWithContentsOfURL:url error:&error];
    
    //设置播放器属性
    _audioPlayer.numberOfLoops = 0;// 不循环
    _audioPlayer.volume = 0.5; // 音量
    [_audioPlayer prepareToPlay];// 加载音频文件到缓存【这个函数在调用play函数时会自动调用】
    
    if(error){
        NSLog(@"初始化播放器过程发生错误,错误信息:%@",error.localizedDescription);
        return nil;
    }
    
    return _audioPlayer;
}

// 定时更新
- (void)update {
    if(_audioRecorder) {
        // 1.更新录音时间,单位秒
        int curInterval = [_audioRecorder currentTime];
        _recordTime.text = [NSString stringWithFormat:@"%02d:%02d",curInterval/60,curInterval%60];
        // 2.声波显示
        //更新声波值
        [self.audioRecorder updateMeters];
        //第一个通道的音频，音频强度范围:[-160~0],这里调整到0~160
        float power = [self.audioRecorder averagePowerForChannel:0] + 160;
        [_processView setProgress:power/160.0];
    }
}


// 录音设置
-(NSDictionary *)getAudioSetting{
    // LinearPCM 是iOS的一种无损编码格式,但是体积较为庞大
    // 录音设置信息字典
    NSMutableDictionary *recordSettings = [[NSMutableDictionary alloc] init];
    // 录音格式
    [recordSettings setValue :@(kAudioFormatLinearPCM) forKey: AVFormatIDKey];
    // 采样率
    [recordSettings setValue :@11025.0 forKey: AVSampleRateKey];
    // 通道数(双通道)
    [recordSettings setValue :@2 forKey: AVNumberOfChannelsKey];
    // 每个采样点位数（有8、16、24、32）
    [recordSettings setValue :@16 forKey: AVLinearPCMBitDepthKey];
    // 采用浮点采样
    [recordSettings setValue:@YES forKey:AVLinearPCMIsFloatKey];
    // 音频质量
    [recordSettings setValue:@(AVAudioQualityMedium) forKey:AVEncoderAudioQualityKey];
    // 其他可选的设置
    // ... ...
    
    return recordSettings;
}

// 删除filepathCaf路径下的音频文件
-(void)deleteRecord{
    NSFileManager* fileManager=[NSFileManager defaultManager];
    if ([[NSFileManager defaultManager] fileExistsAtPath:self.filepathCaf]) {
        // 文件已经存在
        if ([fileManager removeItemAtPath:self.filepathCaf error:nil]) {
            NSLog(@"删除成功");
        }else {
            NSLog(@"删除失败");
        }
    }else {
        return; // 文件不存在无需删除
    }
}

#pragma mark -录音流程控制函数
// 开始录音或者继续录音
- (IBAction)startOrResumeRecord {
    // 注意调用audiorecorder的get方法
    if (![self.audioRecorder isRecording]) {
        // 如果该路径下的音频文件录制过则删除
        [self deleteRecord];
        // 开始录音，会取得用户使用麦克风的同意
        [_audioRecorder record];
    }
}

// 录音暂停
- (IBAction)pauseRecord {
    if (_audioRecorder) {
        [_audioRecorder pause];
    }
}

// 结束录音
- (IBAction)stopRecord {
    [_audioRecorder stop];
}

#pragma mark -录音播放
// 播放录制好的音频
- (IBAction)playRecordedAudio {
    // 没有文件不播放
    if (![[NSFileManager defaultManager] fileExistsAtPath:self.filepathCaf]) return;
    // 播放最新的录音
    [self.audioPlayer play];
}

@end
