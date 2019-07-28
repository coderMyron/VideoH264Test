//
//  ViewController.m
//  VideoH264Test
//
//  Created by Myron on 2019/6/1.
//  Copyright © 2019 Myron. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <VideoToolbox/VideoToolbox.h>
#import "AACEncoder.h"
#import "libyuv.h"


@interface ViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate,AVCaptureAudioDataOutputSampleBufferDelegate,AVCaptureFileOutputRecordingDelegate >
{
    AVCaptureSession *mSession;
    AVCaptureConnection *videoConnect;
    AVCaptureDeviceInput *videoInput;
    AVCaptureVideoPreviewLayer *previewLayer;
    AVCaptureMovieFileOutput *movieFileOutput;
    BOOL isRecording;
    
    //视频编码
    NSMutableData *_data;
    NSString *h264File;
    NSFileHandle *fileHandle;
    BOOL startCalled;
    UIButton *startBtn;
    
    int frameID;
    VTCompressionSessionRef compressionSession;
    BOOL isKeep;
    AACEncoder *aacEncoder;
}
@property (weak, nonatomic) IBOutlet UIButton *recordBtn;
@end

@implementation ViewController

- (IBAction)swichDevices:(UIButton *)sender {
    [self swichDevice];
}

- (IBAction)record:(UIButton *)sender {
    if (isRecording) {
        [self stopRecord];
    } else {
        [self recordeFile];
    }
}


- (void)viewDidLoad {
    [super viewDidLoad];
    
    isRecording = NO;
    
    startCalled = YES;
    isKeep = NO;
    _data = [[NSMutableData alloc] init];
    [self initStartBtn];
    
    //1.1创建Session
    AVCaptureSession *session = [[AVCaptureSession alloc] init];
    session.sessionPreset = AVCaptureSessionPreset1280x720;
    mSession = session;

    //设置视频输入输出
    [self setupVideoSource:session];
    //设置音频输入输出
    [self setupAudioSource:session];
    //设置预览图层
    [self setupPreviewLayer:session];

    //1.5 开始采集
    [session startRunning];
    
}

-(void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self judgeCameraLimits];
}

- (void)judgeCameraLimits{
    /// 先判断摄像头硬件是否好用
    if([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera])
    {
        // 用户是否允许摄像头使用
        NSString * mediaType = AVMediaTypeVideo;
        AVAuthorizationStatus  authorizationStatus = [AVCaptureDevice authorizationStatusForMediaType:mediaType];
        NSLog(@"%ld",authorizationStatus);
        // 不允许弹出提示框
        if (authorizationStatus == AVAuthorizationStatusRestricted|| authorizationStatus == AVAuthorizationStatusDenied) {

            NSLog(@"摄像头访问受限,前往设置") ;
            UIAlertController *alerController = [UIAlertController alertControllerWithTitle:@"提示" message:@"摄像头访问受限,前往设置" preferredStyle:(UIAlertControllerStyleAlert)];
            [alerController addAction:[UIAlertAction actionWithTitle:@"取消" style:(UIAlertActionStyleCancel) handler:^(UIAlertAction * _Nonnull action) {
                NSLog(@"取消");
            }]];
            [alerController addAction:[UIAlertAction actionWithTitle:@"设置" style:(UIAlertActionStyleDefault) handler:^(UIAlertAction * _Nonnull action) {
                NSLog(@"设置");
                [[UIApplication sharedApplication]openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
            }]];
            
            //这也是一个方法解决不弹窗问题(控制器还没有生成问题)
//            UIViewController *topRootViewController = [[UIApplication  sharedApplication] keyWindow].rootViewController;
//
//            // 在这里加一个这个样式的循环
//            while (topRootViewController.presentedViewController)
//            {
//                // 这里固定写法
//                topRootViewController = topRootViewController.presentedViewController;
//            }
//            [topRootViewController presentViewController:alerController animated:YES completion:nil];
            [self presentViewController:alerController animated:YES completion:nil];
            
            
            
        }else {
            // 这里是摄像头可以使用的处理逻辑
            NSLog(@"摄像头可以使用") ;
        }
    } else {
        // 硬件问题提示
        NSLog(@"请检查手机摄像头设备") ;
        UIAlertController *alerController = [UIAlertController alertControllerWithTitle:@"提示" message:@"请检查手机摄像头设备" preferredStyle:(UIAlertControllerStyleAlert)];
        [alerController addAction:[UIAlertAction actionWithTitle:@"取消" style:(UIAlertActionStyleCancel) handler:^(UIAlertAction * _Nonnull action) {
            NSLog(@"取消");
        }]];
        [self presentViewController:alerController animated:YES completion:nil];
    }
}

- (void)setupVideoSource:(AVCaptureSession *) session
{
    //1.2 设置视频的输入
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    NSLog(@"%@",device);
    if (device == nil) {
        return;
    }
    NSError *error;
    videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:device error:&error];
    if ([session canAddInput:videoInput]) {
        [session addInput:videoInput];
    }
    
    //1.3 设置视频的输出
    AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    //有些格式手机不支持，所以用默认就行
//    NSString* key = (NSString*)kCVPixelBufferPixelFormatTypeKey;
//    //      kCVPixelFormatType_420YpCbCr8Planar is YUV420
//    //      kCVPixelFormatType_420YpCbCr8BiPlanarFullRange is NV12
//    NSNumber* val = [NSNumber
//                     numberWithUnsignedInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange];
//    NSDictionary* videoSettings =
//    [NSDictionary dictionaryWithObject:val forKey:key];
//    NSError *lockError;
//    [device lockForConfiguration:&lockError];
//    if (lockError == nil) {
//        NSLog(@"cameraDevice.activeFormat.videoSupportedFrameRateRanges IS %@",[device.activeFormat.videoSupportedFrameRateRanges objectAtIndex:0]);
//
//        if (device.activeFormat.videoSupportedFrameRateRanges){
//
//            [device setActiveVideoMinFrameDuration:CMTimeMake(1, CAPTURE_FRAMES_PER_SECOND)];
//            [device setActiveVideoMaxFrameDuration:CMTimeMake(1, CAPTURE_FRAMES_PER_SECOND)];
//        }
//    }else{
//        // handle error2
//        NSLog(@"handle error2");
//    }
//    [device unlockForConfiguration];
//    output.videoSettings = videoSettings;
    
    [output setSampleBufferDelegate:self queue:queue];
    [output setAlwaysDiscardsLateVideoFrames:YES];
    if ([session canAddOutput:output]) {
        [session addOutput:output];
    }
    // 视频输出的方向
    // 注意: 设置方向, 必须在将output添加到session之后
    videoConnect = [output connectionWithMediaType:AVMediaTypeVideo];
    if (videoConnect.isVideoOrientationSupported) {
        videoConnect.videoOrientation = AVCaptureVideoOrientationPortrait;
    } else {
        NSLog(@"不支持设置方向");
    }
    
}

- (void)setupVideoSession {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    
    h264File = [documentsDirectory stringByAppendingPathComponent:@"test.h264"];
    [fileManager removeItemAtPath:h264File error:nil];
    [fileManager createFileAtPath:h264File contents:nil attributes:nil];
    fileHandle = [NSFileHandle fileHandleForWritingAtPath:h264File];
    
    // 1.用于记录当前是第几帧数据(画面帧数非常多)
    frameID = 0;
    
    // 2.录制视频的宽度&高度
    int width = [UIScreen mainScreen].bounds.size.width;
    int height = [UIScreen mainScreen].bounds.size.height;
    
    // 3.创建CompressionSession对象,该对象用于对画面进行编码
    // kCMVideoCodecType_H264 : 表示使用h.264进行编码
    // didCompressH264 : 当一次编码结束会在该函数进行回调,可以在该函数中将数据,写入文件中
    VTCompressionSessionCreate(NULL, width, height, kCMVideoCodecType_H264, NULL, NULL, NULL, didCompressH264, (__bridge void *)(self),  &compressionSession);

    // 4.设置实时编码输出（直播必然是实时输出,否则会有延迟）
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);

    // 5.设置期望帧率(每秒多少帧,如果帧率过低,会造成画面卡顿)
    int fps = 30;
    CFNumberRef  fpsRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &fps);
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_ExpectedFrameRate, fpsRef);


    // 6.设置码率(码率: 编码效率, 码率越高,则画面越清晰, 如果码率较低会引起马赛克 --> 码率高有利于还原原始画面,但是也不利于传输)
    int bitRate = 800*1024;
    CFNumberRef bitRateRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &bitRate);
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_AverageBitRate, bitRateRef);
    NSArray *limit = @[@(bitRate * 1.5/8), @(1)];// byte 除以8是将bit转化为byte
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_DataRateLimits, (__bridge CFArrayRef)limit);

    // 7.设置关键帧（GOPsize)间隔
    int frameInterval = 30;
    CFNumberRef  frameIntervalRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &frameInterval);
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_MaxKeyFrameInterval, frameIntervalRef);

    // 8.基本设置结束, 准备进行编码
    VTCompressionSessionPrepareToEncodeFrames(compressionSession);
}

//转化
-(CVPixelBufferRef)convertVideoSmapleBufferToYuvData:(CMSampleBufferRef) videoSample{
    
    //    1.
    //CVPixelBufferRef是CVImageBufferRef的别名，两者操作几乎一致。
    //获取CMSampleBuffer的图像地址
    CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(videoSample);
    //表示开始操作数据
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    //图像宽度（像素）
    size_t pixelWidth = CVPixelBufferGetWidth(pixelBuffer);
    //图像高度（像素）
    size_t pixelHeight = CVPixelBufferGetHeight(pixelBuffer);
    //获取CVImageBufferRef中的y数据
    uint8_t *y_frame = (unsigned char *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
    //获取CMVImageBufferRef中的uv数据
    uint8_t *uv_frame =(unsigned char *) CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
    
    //y stride
    size_t plane1_stride = CVPixelBufferGetBytesPerRowOfPlane (pixelBuffer, 0);
    //uv stride
    size_t plane2_stride = CVPixelBufferGetBytesPerRowOfPlane (pixelBuffer, 1);
    //y_size
    size_t plane1_size = plane1_stride * CVPixelBufferGetHeightOfPlane(pixelBuffer, 0);
    //uv_size
    size_t plane2_size = CVPixelBufferGetBytesPerRowOfPlane (pixelBuffer, 1) * CVPixelBufferGetHeightOfPlane(pixelBuffer, 1);
    //yuv_size(内存空间)
    size_t frame_size = plane1_size + plane2_size;
    
    //开辟frame_size大小的内存空间用于存放转换好的i420数据
    uint8* buffer = (unsigned char *)malloc(frame_size);
    //buffer为这段内存的首地址,plane1_size代表这一帧中y数据的长度
    uint8* dst_u = buffer + plane1_size;
    //dst_u为u数据的首地,plane1_size/4为u数据的长度
    uint8* dst_v = dst_u + plane1_size/4;
    
    
    // Let libyuv convert
   NV12ToI420(y_frame,plane1_stride,
                       uv_frame, plane2_stride,
                       buffer, plane1_stride,
                       dst_u,plane2_stride/2,
                       dst_v, plane2_stride/2,
                       pixelWidth, pixelHeight);
    
    
    int shareSWidth = 480;
    int shareSHeight = 720;
    //    2
    //scale-size
    int scale_yuvBufSize = shareSWidth * shareSHeight * 3 / 2;
    //uint8_t* scale_yuvBuf= new uint8_t[scale_yuvBufSize];
    uint8* scale_yuvBuf = (unsigned char *)malloc(scale_yuvBufSize);
    
    //scale-stride
    const int32 scale_uv_stride = (shareSWidth + 1) / 2;
    
    //scale-length
    const int scale_y_length = shareSWidth * shareSHeight;
    int scale_uv_length = scale_uv_stride * ((shareSWidth+1) / 2);
    
    unsigned char *scale_Y_data_Dst = scale_yuvBuf;
    unsigned char *scale_U_data_Dst = scale_yuvBuf + scale_y_length;
    unsigned char *scale_V_data_Dst = scale_U_data_Dst + scale_y_length/4;
    
    
    I420Scale(buffer, plane1_stride, dst_u, plane2_stride/2, dst_v, plane2_stride/2, pixelWidth, pixelHeight, scale_Y_data_Dst, shareSWidth,
                      scale_U_data_Dst, scale_uv_stride,
                      scale_V_data_Dst, scale_uv_stride,
                      shareSWidth, shareSHeight,
                      kFilterNone);
    
    
    //    3.
    uint8 *dst_y = (uint8 *)malloc((shareSWidth * shareSHeight * 3) >> 1);
    int dst_Stride_Y = shareSWidth;
    uint8 *dst_uv = dst_y + shareSWidth*shareSHeight;
    int dst_Stride_uv = shareSWidth/2;
    
    I420ToNV12(scale_Y_data_Dst, shareSWidth,
                       scale_U_data_Dst, scale_uv_stride,
                       scale_V_data_Dst, scale_uv_stride,dst_y, dst_Stride_Y, dst_uv, dst_Stride_Y,shareSWidth, shareSHeight);
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    free(buffer);
    free(scale_yuvBuf);
    
    //转化
    NSDictionary *pixelAttributes = @{(id)kCVPixelBufferIOSurfacePropertiesKey : @{}};
    CVPixelBufferRef pixelBuffer1 = NULL;
    CVReturn result = CVPixelBufferCreate(kCFAllocatorDefault,
                                          shareSWidth,shareSHeight,kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
                                          (__bridge CFDictionaryRef)pixelAttributes,&pixelBuffer1);
    
    CVPixelBufferLockBaseAddress(pixelBuffer1, 0);
    uint8_t *yDestPlane = (uint8*)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer1, 0);
    memcpy(yDestPlane, dst_y, shareSWidth * shareSHeight);
    uint8_t *uvDestPlane = (uint8*)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer1, 1);
    memcpy(uvDestPlane, dst_uv, shareSWidth * shareSHeight/2);
    if (result != kCVReturnSuccess) {
        NSLog(@"Unable to create cvpixelbuffer %d", result);
    }
    CVPixelBufferUnlockBaseAddress(pixelBuffer1, 0);
    free(dst_y);
    //    CVPixelBufferRelease(pixelBuffer1);
    
    return pixelBuffer1;
}

void didCompressH264(void *outputCallbackRefCon, void *sourceFrameRefCon, OSStatus status, VTEncodeInfoFlags infoFlags,
                     CMSampleBufferRef sampleBuffer ){
    // 1.判断状态是否等于没有错误
    if (status != noErr) {
        return;
    }
    
    // 2.根据传入的参数获取对象
    ViewController* encoder = (__bridge ViewController*)outputCallbackRefCon;
    
    // 3.判断是否是关键帧
//    bool isKeyframe = !CFDictionaryContainsKey( (CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true), 0)), kCMSampleAttachmentKey_NotSync);
    CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true);
    CFDictionaryRef dict = CFArrayGetValueAtIndex(attachments, 0);
    bool isKeyframe = !CFDictionaryContainsKey(dict, kCMSampleAttachmentKey_NotSync);
    // 判断当前帧是否为关键帧
    // 获取sps & pps数据
    if (isKeyframe)
    {
        // 获取编码后的信息（存储于CMFormatDescriptionRef中）
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
        
        // 获取SPS信息
        size_t sparameterSetSize, sparameterSetCount;
        const uint8_t *sparameterSet;
        CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 0, &sparameterSet, &sparameterSetSize, &sparameterSetCount, 0 );
        
        // 获取PPS信息
        size_t pparameterSetSize, pparameterSetCount;
        const uint8_t *pparameterSet;
        CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 1, &pparameterSet, &pparameterSetSize, &pparameterSetCount, 0 );
        
        // 装sps/pps转成NSData，以方便写入文件
        NSData *sps = [NSData dataWithBytes:sparameterSet length:sparameterSetSize];
        NSData *pps = [NSData dataWithBytes:pparameterSet length:pparameterSetSize];
        
        // 写入文件
        [encoder gotSpsPps:sps pps:pps];
    }
    
    // 获取数据块
    CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t length, totalLength;
    char *dataPointer;
    OSStatus statusCodeRet = CMBlockBufferGetDataPointer(dataBuffer, 0, &length, &totalLength, &dataPointer);
    if (statusCodeRet == noErr) {
        size_t bufferOffset = 0;
        static const int AVCCHeaderLength = 4; // 返回的nalu数据前四个字节不是0001的startcode，而是大端模式的帧长度length
        
        //注意每个buffer要减去四字节, 而这里的四字节Header并不是0001的开始码, 而是大端模式的帧长度length
        // 循环获取nalu数据
        while (bufferOffset < totalLength - AVCCHeaderLength) {
            uint32_t NALUnitLength = 0;
            // Read the NAL unit length
            memcpy(&NALUnitLength, dataPointer + bufferOffset, AVCCHeaderLength);
            
            // 从大端转系统端
            NALUnitLength = CFSwapInt32BigToHost(NALUnitLength);
            
            NSData* data = [[NSData alloc] initWithBytes:(dataPointer + bufferOffset + AVCCHeaderLength) length:NALUnitLength];
            [encoder gotEncodedData:data isKeyFrame:isKeyframe];
            
            // 移动到写一个块，转成NALU单元
            // Move to the next NAL unit in the block buffer
            bufferOffset += AVCCHeaderLength + NALUnitLength;
        }
    }
}

- (void)encodeSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    // 1.将sampleBuffer转成imageBuffer
    CVImageBufferRef imageBuffer = (CVImageBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
    
    // 2.根据当前的帧数,创建CMTime的时间
    CMTime presentationTimeStamp = CMTimeMake(frameID++, 1000);
    VTEncodeInfoFlags flags;
    
    // 3.开始编码该帧数据
    OSStatus statusCode = VTCompressionSessionEncodeFrame(compressionSession,
                                                          imageBuffer,
                                                          presentationTimeStamp,
                                                          kCMTimeInvalid,
                                                          NULL, (__bridge void * _Nullable)(self), &flags);
    if (statusCode == noErr) {
        NSLog(@"H264: VTCompressionSessionEncodeFrame Success");
    }
}

- (void)setupAudioSource:(AVCaptureSession *) session
{
    aacEncoder = [[AACEncoder alloc] init];
    
    // 1.创建输入
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:(AVMediaTypeAudio)];
    
    NSError *error;
    AVCaptureDeviceInput *audioInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    
    // 2.创建输出源
    AVCaptureAudioDataOutput *audioOutput = [[AVCaptureAudioDataOutput alloc] init];
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    [audioOutput setSampleBufferDelegate:self queue:queue];
    
    // 3.将输入&输出添加到会话中
    if ([session canAddInput:audioInput]) {
        [session addInput:audioInput];
    }
    if ([session canAddOutput:audioOutput]) {
        [session addOutput:audioOutput];
    }
}

-(void)setupPreviewLayer:(AVCaptureSession *) session {
    //1.4 添加预览层
    AVCaptureVideoPreviewLayer *layer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
    layer.frame = self.view.bounds;
    [self.view.layer insertSublayer:layer atIndex:0];
    previewLayer = layer;
}

#pragma mark 采集音视频数据
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection{
//    CMTime pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
//    double dPTS = (double)(pts.value) / pts.timescale;
//    NSLog(@"DPTS is %f",dPTS);
    
    if (connection == videoConnect) {
        if (isKeep) {
            NSLog(@"视频数据");
            //         [h264Encoder encode:sampleBuffer]
            [self encodeSampleBuffer:sampleBuffer];
        }
        
    } else {
        if (isKeep) {
            NSLog(@"音频数据");
            [aacEncoder encodeSampleBuffer:sampleBuffer completionBlock:^(NSData *encodedData, NSError *error) {
                if (encodedData) {
                    
                    NSLog(@"Audio data (%lu): %@", (unsigned long)encodedData.length, encodedData.description);
                    [_data appendData:encodedData];
                    
                    
                } else {
                    NSLog(@"Error encoding AAC: %@", error);
                }
            }];
        }
        
    }
    
}

- (void)gotSpsPps:(NSData*)sps pps:(NSData*)pps
{
    // 1.拼接NALU的header
    const char bytes[] = "\x00\x00\x00\x01";
    size_t length = (sizeof bytes) - 1;
    NSData *ByteHeader = [NSData dataWithBytes:bytes length:length];
    
    // 2.将NALU的头&NALU的体写入文件
    [fileHandle writeData:ByteHeader];
    [fileHandle writeData:sps];
    [fileHandle writeData:ByteHeader];
    [fileHandle writeData:pps];
}
- (void)gotEncodedData:(NSData*)data isKeyFrame:(BOOL)isKeyFrame
{
    NSLog(@"gotEncodedData %d", (int)[data length]);
    if (fileHandle != NULL)
    {
        const char bytes[] = "\x00\x00\x00\x01";
        size_t length = (sizeof bytes) - 1; //string literals have implicit trailing '\0'
        NSData *ByteHeader = [NSData dataWithBytes:bytes length:length];
        [fileHandle writeData:ByteHeader];
        [fileHandle writeData:data];
        
    }
}

-(void)swichDevice {
    if (videoInput == nil) {
        return;
    }
    // 2.获取当前镜头
    AVCaptureDevicePosition position = (videoInput.device.position == AVCaptureDevicePositionFront)? AVCaptureDevicePositionBack : AVCaptureDevicePositionFront;
    // 3.创建新的input
    AVCaptureDevice *device;
    device = [AVCaptureDevice defaultDeviceWithDeviceType: AVCaptureDeviceTypeBuiltInDuoCamera
                                                mediaType: AVMediaTypeVideo
                                                 position: position];
    if (device == nil) {
        device = [AVCaptureDevice defaultDeviceWithDeviceType: AVCaptureDeviceTypeBuiltInWideAngleCamera
                                                    mediaType: AVMediaTypeVideo
                                                     position: position];
    }
    NSLog(@"%@",device);
    if (device == nil) {
        return;
    }
    NSError *error;
    AVCaptureDeviceInput *newVideoInput = [[AVCaptureDeviceInput alloc] initWithDevice:device error:&error];
    if (newVideoInput) {
        // 4.移除旧输入，添加新输入
        [mSession beginConfiguration];
        [mSession removeInput:videoInput];
        [mSession addInput:newVideoInput];
        [mSession commitConfiguration];
        
        // 5.保存新输入
        videoInput = newVideoInput;
    }
    
}

-(void)recordeFile {
    AVAuthorizationStatus  authorizationStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    NSLog(@"%ld",authorizationStatus);
    if (authorizationStatus != AVAuthorizationStatusAuthorized) {
        return;
    }
    // 添加文件输出
    movieFileOutput = [[AVCaptureMovieFileOutput alloc] init];
    if ([mSession canAddOutput:movieFileOutput]) {
        [mSession addOutput:movieFileOutput];
        AVCaptureConnection *connection = [movieFileOutput connectionWithMediaType:AVMediaTypeVideo];
        [connection setPreferredVideoStabilizationMode:(AVCaptureVideoStabilizationModeAuto)];
        NSURL *url;
        NSString *filePath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        filePath =  [filePath stringByAppendingPathComponent:@"video.mp4"];
        //判断test文件是否存在
//        NSFileManager * fm = [NSFileManager defaultManager];
//        if ([fm fileExistsAtPath:filePath]) {
//            NSLog(@"video.mp4文件存在");
//            [fm removeItemAtPath:filePath error:nil];
//        }
        
        url = [NSURL fileURLWithPath:filePath];
        [movieFileOutput startRecordingToOutputFileURL:url recordingDelegate:self];
        isRecording = YES;
        [_recordBtn setTitle:@"停止" forState:UIControlStateNormal];
    }
    
}

-(void)stopRecord {
    [_recordBtn setTitle:@"录制" forState:UIControlStateNormal];
    if (movieFileOutput) {
        isRecording = NO;
        [movieFileOutput stopRecording];
    }
}

-(void)captureOutput:(AVCaptureFileOutput *)output didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray<AVCaptureConnection *> *)connections{
    NSLog(@"开始录制");
}

-(void)captureOutput:(AVCaptureFileOutput *)output didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray<AVCaptureConnection *> *)connections error:(NSError *)error{
    NSLog(@"停止录制");
}

- (void)dealloc
{
    NSLog(@"dealloc");
    if (previewLayer) {
        [previewLayer removeFromSuperlayer];
    }
    if (mSession) {
        [mSession stopRunning];
        mSession = nil;
    }
    [self stopRecord];
    
}

- (void)initStartBtn
{
    startBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    startBtn.frame = CGRectMake(0, 0, 100, 30);
    startBtn.center = self.view.center;
    [startBtn addTarget:self action:@selector(startBtnClicked) forControlEvents:UIControlEventTouchUpInside];
    [startBtn setTitle:@"Start" forState:UIControlStateNormal];
    [startBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [self.view addSubview:startBtn];
}

#pragma mark
#pragma mark - 录制
- (void)startBtnClicked
{
    if (startCalled)
    {
        [self startCamera];
        startCalled = NO;
        [startBtn setTitle:@"Stop" forState:UIControlStateNormal];
        
    }
    else
    {
        [startBtn setTitle:@"Start" forState:UIControlStateNormal];
        startCalled = YES;
        [self stopCarmera];
    }
    
}

- (void) startCamera
{
    isKeep = YES;
    [self setupVideoSession];
}

- (void) stopCarmera
{
    isKeep = NO;
    VTCompressionSessionCompleteFrames(compressionSession, kCMTimeInvalid);
    [fileHandle closeFile];
    fileHandle = NULL;
    
    // 获取程序Documents目录路径
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];

    NSMutableString * path = [[NSMutableString alloc]initWithString:documentsDirectory];
    [path appendString:@"/AACFile"];

    [_data writeToFile:path atomically:YES];
    
}

@end
