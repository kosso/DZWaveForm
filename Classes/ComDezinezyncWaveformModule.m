//
//
//  DZWaveForm
//
//  Created by Nikhil Nigade on 18/11/13.
//
//  Updated/hacked/broken/fixed? by Kosso - Nov. 2013.


#import "ComDezinezyncWaveformModule.h"

#define absX(x) (x<0?0-x:x)
#define minMaxX(x,mn,mx) (x<=mn?mn:(x>=mx?mx:x))
#define noiseFloor (-50.0)
#define decibel(amplitude) (20.0 * log10(absX(amplitude)/32767.0))
#define imgExt @"png"
#define imageToData(x) UIImagePNGRepresentation(x)

@implementation ComDezinezyncWaveformModule

#pragma mark Internal

// this is generated for your module, please do not change it
-(id)moduleGUID
{
    return @"2c95c5b0-2655-4f7d-8332-02b520865064";
}

// this is generated for your module, please do not change it
-(NSString*)moduleId
{
    return @"com.dezinezync.waveform";
}

#pragma mark Lifecycle

-(void)startup
{
    // this method is called when the module is first loaded
    // you *must* call the superclass
    [super startup];
    
    NSLog(@"[INFO] %@ loaded",self);
}

-(void)shutdown:(id)sender
{
    // this method is called when the module is being unloaded
    // typically this is during shutdown. make sure you don't do too
    // much processing here or the app will be quit forceably
    
    // you *must* call the superclass
    [super shutdown:sender];
}

#pragma mark Cleanup 

-(void)dealloc
{
    // release any resources that have been retained by the module
    NSLog(@"Deallocating");
    [super dealloc];
}

#pragma mark Internal Memory Management

-(void)didReceiveMemoryWarning:(NSNotification*)notification
{
    // optionally release any resources that can be dynamically
    // reloaded once memory is available - such as caches
    [super didReceiveMemoryWarning:notification];
}

#pragma mark Listener Notifications

-(void)_listenerAdded:(NSString *)type count:(int)count
{
    if (count == 1 && [type isEqualToString:@"my_event"])
    {
        // the first (of potentially many) listener is being added 
        // for event named 'my_event'
    }
}

-(void)_listenerRemoved:(NSString *)type count:(int)count
{
    if (count == 0 && [type isEqualToString:@"my_event"])
    {
        // the last listener called for event named 'my_event' has
        // been removed, we can optionally clean up any resources
        // since no body is listening at this point for that event
    }
}

#pragma Public APIs

/*
    Waveform algorithm based on SO answer here : 
    http://stackoverflow.com/questions/8298610/waveform-on-ios

    Also: original solution for the above here (with non-Logarithmic version)
    http://stackoverflow.com/questions/5032775/drawing-waveform-with-avassetreader

*/

//URL is the file's url. In Ti, do file.resolve() and pass that as the param.
-(id)analyze:(id)args  // fileUrl, useLogarithym 
{
    NSString *theString = [TiUtils stringValue:[args objectAtIndex:0]];

    // Just a quick dirty hack to test bloth analysis types.
    BOOL *useLog = [TiUtils boolValue:[args objectAtIndex:1] def:NO];
    
    /* 
    Todo: 
    - Check to make sure the file exists.
    - Would be good to also set image size and left/right colours and background colour/transparency.
    - Fix single channel samples. If waveform channels are set to 'channelCount' instead of '2' when the audio is mono (ie: 1), 
      the waveform is not correct. Samples and wave placement seems to be very off. Demonstrated by using the waveform in a Ti audioPlayer and 
      tracing the progress position along the top of it while playing. 
    - Hmmmm ... 
    */

    NSURL *theURL = [NSURL fileURLWithPath:theString];
    AVURLAsset *urlA = [AVURLAsset URLAssetWithURL:theURL options:nil];
    
    UIImage *theImage = nil;

    if(useLog){
        // Logarithmic version
        theImage = [self renderPNGAudioPictogramLogForAsset:urlA];
    } else {
        // Non-Logarithmic version
        theImage = [self renderPNGAudioPictogramForAsset:urlA];
    }

    if(theImage != nil)
    {
        TiBlob *theBlob = [[TiBlob alloc] initWithImage:theImage];
        
        if(theBlob != nil)
        {
            //[theString release];
            //[theURL release];
           
            return theBlob;
        }
        else
        {
            //[theString release];
            //[theURL release];

            return [NSNull null];
        }
    }
    else
    {
        //[theString release];
        //[theURL release];
        
        return [NSNull null];
    }
    
}

-(UIImage *) audioImageGraph:(SInt16 *) samples
                normalizeMax:(SInt16) normalizeMax
                 sampleCount:(NSInteger) sampleCount 
                channelCount:(NSInteger) channelCount
                 imageHeight:(float) imageHeight {

    CGSize imageSize = CGSizeMake(sampleCount, imageHeight);
    UIGraphicsBeginImageContext(imageSize);
    CGContextRef context = UIGraphicsGetCurrentContext();

    CGContextSetFillColorWithColor(context, [UIColor clearColor].CGColor);
    CGContextSetAlpha(context,1.0);
    CGRect rect;
    rect.size = imageSize;
    rect.origin.x = 0;
    rect.origin.y = 0;

    CGColorRef leftcolor = [[UIColor whiteColor] CGColor];
    CGColorRef rightcolor = [[UIColor whiteColor] CGColor];

    CGContextFillRect(context, rect);

    CGContextSetLineWidth(context, 1.0);

    float halfGraphHeight = (imageHeight / 2) / (float) channelCount ;
    float centerLeft = halfGraphHeight;
    float centerRight = (halfGraphHeight*3) ; 
    float sampleAdjustmentFactor = (imageHeight/ (float) channelCount) / (float) normalizeMax;

    for (NSInteger intSample = 0 ; intSample < sampleCount ; intSample ++ ) {
        SInt16 left = *samples++;
        float pixels = (float) left;
        pixels *= sampleAdjustmentFactor;
        CGContextMoveToPoint(context, intSample, centerLeft-pixels);
        CGContextAddLineToPoint(context, intSample, centerLeft+pixels);
        CGContextSetStrokeColorWithColor(context, leftcolor);
        CGContextStrokePath(context);

        if (channelCount==2) {
            SInt16 right = *samples++;
            float pixels = (float) right;
            pixels *= sampleAdjustmentFactor;
            CGContextMoveToPoint(context, intSample, centerRight - pixels);
            CGContextAddLineToPoint(context, intSample, centerRight + pixels);
            CGContextSetStrokeColorWithColor(context, rightcolor);
            CGContextStrokePath(context); 
        }
    }

    // Create new image
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();

    // Tidy up
    UIGraphicsEndImageContext();   

    return newImage;
}

-(UIImage *)audioImageLogGraph:(Float32 *) samples
                  normalizeMax:(Float32) normalizeMax
                   sampleCount:(NSInteger) sampleCount
                  channelCount:(NSInteger) channelCount
                   imageHeight:(float) imageHeight {
    /*
    - Make imageHeight configurable
    */

    CGSize imageSize = CGSizeMake(sampleCount, imageHeight);
    UIGraphicsBeginImageContext(imageSize);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextSetFillColorWithColor(context, [UIColor clearColor].CGColor); // Give it a transparent background.

    CGContextSetAlpha(context,1.0);
    CGRect rect;
    rect.size = imageSize;
    rect.origin.x = 0;
    rect.origin.y = 0;
    
    CGColorRef leftcolor = [[UIColor whiteColor] CGColor];  // Make this configurable. 
    CGColorRef rightcolor = [[UIColor whiteColor] CGColor]; // Make this configurable. 
    
    CGContextFillRect(context, rect);
    
    CGContextSetLineWidth(context, 1.0);
    
    float halfGraphHeight = (imageHeight / 2) / (float) channelCount ;
    float centerLeft = halfGraphHeight;
    float centerRight = (halfGraphHeight*3) ;
    float sampleAdjustmentFactor = (imageHeight/ (float) channelCount) / (normalizeMax - noiseFloor) / 2;
    
    for (NSInteger intSample = 0 ; intSample < sampleCount ; intSample ++ ) {
        Float32 left = *samples++;
        float pixels = (left - noiseFloor) * sampleAdjustmentFactor;
        CGContextMoveToPoint(context, intSample, centerLeft-pixels);
        CGContextAddLineToPoint(context, intSample, centerLeft+pixels);
        CGContextSetStrokeColorWithColor(context, leftcolor);
        CGContextStrokePath(context);
        
        if (channelCount==2) {
            Float32 right = *samples++;
            float pixels = (right - noiseFloor) * sampleAdjustmentFactor;
            CGContextMoveToPoint(context, intSample, centerRight - pixels);
            CGContextAddLineToPoint(context, intSample, centerRight + pixels);
            CGContextSetStrokeColorWithColor(context, rightcolor);
            CGContextStrokePath(context);
        }
    }
    
    // Create new image
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    
    // Tidy up
    UIGraphicsEndImageContext();
    
    return newImage;
}

-(UIImage *) renderPNGAudioPictogramForAsset:(AVURLAsset *)songAsset {
    
    // Non-Logarithmic version 
    // see : http://stackoverflow.com/questions/5032775/drawing-waveform-with-avassetreader

    NSError * error = nil;

    AVAssetReader * reader = [[AVAssetReader alloc] initWithAsset:songAsset error:&error];
    AVAssetTrack * songTrack = [songAsset.tracks objectAtIndex:0];

    NSDictionary* outputSettingsDict = [[NSDictionary alloc] initWithObjectsAndKeys:
                                        [NSNumber numberWithInt:kAudioFormatLinearPCM],AVFormatIDKey,
                                        //     [NSNumber numberWithInt:44100.0],AVSampleRateKey, /*Not Supported*/
                                        //     [NSNumber numberWithInt: 2],AVNumberOfChannelsKey,    /*Not Supported*/
                                        [NSNumber numberWithInt:16],AVLinearPCMBitDepthKey,
                                        [NSNumber numberWithBool:NO],AVLinearPCMIsBigEndianKey,
                                        [NSNumber numberWithBool:NO],AVLinearPCMIsFloatKey,
                                        [NSNumber numberWithBool:NO],AVLinearPCMIsNonInterleaved,
                                        nil];

    AVAssetReaderTrackOutput* output = [[AVAssetReaderTrackOutput alloc] initWithTrack:songTrack outputSettings:outputSettingsDict];

    [reader addOutput:output];
    [output release];

    UInt32 sampleRate,channelCount;

    NSArray* formatDesc = songTrack.formatDescriptions;
    for(unsigned int i = 0; i < [formatDesc count]; ++i) {
        CMAudioFormatDescriptionRef item = (CMAudioFormatDescriptionRef)[formatDesc objectAtIndex:i];
        const AudioStreamBasicDescription* fmtDesc = CMAudioFormatDescriptionGetStreamBasicDescription (item);
        if(fmtDesc ) {

            sampleRate = fmtDesc->mSampleRate;
            channelCount = fmtDesc->mChannelsPerFrame;

            NSLog(@"[INFO] channels:%u, bytes/packet: %u, sampleRate %f",fmtDesc->mChannelsPerFrame, fmtDesc->mBytesPerPacket,fmtDesc->mSampleRate);
        }
    }


    UInt32 bytesPerSample = 2 * channelCount;
    SInt16 normalizeMax = 0;

    NSMutableData * fullSongData = [[NSMutableData alloc] init];
    [reader startReading];


    UInt64 totalBytes = 0; 


    SInt64 totalLeft = 0;
    SInt64 totalRight = 0;
    NSInteger sampleTally = 0;

    NSInteger samplesPerPixel = sampleRate / 50;


    while (reader.status == AVAssetReaderStatusReading){

        AVAssetReaderTrackOutput * trackOutput = (AVAssetReaderTrackOutput *)[reader.outputs objectAtIndex:0];
        CMSampleBufferRef sampleBufferRef = [trackOutput copyNextSampleBuffer];

        if (sampleBufferRef){
            CMBlockBufferRef blockBufferRef = CMSampleBufferGetDataBuffer(sampleBufferRef);

            size_t length = CMBlockBufferGetDataLength(blockBufferRef);
            totalBytes += length;


            NSAutoreleasePool *wader = [[NSAutoreleasePool alloc] init];

            NSMutableData * data = [NSMutableData dataWithLength:length];
            CMBlockBufferCopyDataBytes(blockBufferRef, 0, length, data.mutableBytes);


            SInt16 * samples = (SInt16 *) data.mutableBytes;
            int sampleCount = length / bytesPerSample;
            for (int i = 0; i < sampleCount ; i ++) {

                SInt16 left = *samples++;

                totalLeft  += left;



                SInt16 right;
                if (channelCount==2) {
                    right = *samples++;

                    totalRight += right;
                }

                sampleTally++;

                if (sampleTally > samplesPerPixel) {

                    left  = totalLeft / sampleTally; 

                    SInt16 fix = abs(left);
                    if (fix > normalizeMax) {
                        normalizeMax = fix;
                    }


                    [fullSongData appendBytes:&left length:sizeof(left)];

                    if (channelCount==2) {
                        right = totalRight / sampleTally; 


                        SInt16 fix = abs(right);
                        if (fix > normalizeMax) {
                            normalizeMax = fix;
                        }


                        [fullSongData appendBytes:&right length:sizeof(right)];
                    }

                    totalLeft   = 0;
                    totalRight  = 0;
                    sampleTally = 0;

                }
            }

           [wader drain];

            CMSampleBufferInvalidate(sampleBufferRef);

            CFRelease(sampleBufferRef);
        }
    }

    UIImage *finalImage = nil;

    if (reader.status == AVAssetReaderStatusFailed || reader.status == AVAssetReaderStatusUnknown){
        // Something went wrong. return nil

        return nil;
    }

    if (reader.status == AVAssetReaderStatusCompleted){

        NSLog(@"rendering non-Logarithmic output graphics using normalizeMax %d",normalizeMax);

        finalImage = [self audioImageGraph:(SInt16 *) fullSongData.bytes 
                                 normalizeMax:normalizeMax 
                                  sampleCount:fullSongData.length / 4 
                                 channelCount:2 // Not working correctly when set to chennelCount. Works OK when forced to 2, even if source is mono (1).
                                  imageHeight:100];
    }

    [fullSongData release];
    [reader release];
    
    return finalImage;
}


-(UIImage *)renderPNGAudioPictogramLogForAsset:(AVURLAsset *)songAsset {
    
    NSError *error = nil;
    
    AVAssetReader *reader = [[AVAssetReader alloc] initWithAsset:songAsset error:&error];
    
    if(error != nil)
    {
        NSLog(@"Error: %@", error.localizedDescription);
        return;
    }
    
    if([songAsset.tracks count] == 0)
    {
        NSLog(@"No tracks found in the song asset");
        return;
    }
    
    AVAssetTrack *songTrack = [[songAsset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0];
    
    NSDictionary *outputSettingsDict = [[NSDictionary alloc] initWithObjectsAndKeys:
                                        
                                        [NSNumber numberWithInt:kAudioFormatLinearPCM],AVFormatIDKey,
                                        //     [NSNumber numberWithInt:44100.0],AVSampleRateKey, /*Not Supported*/
                                        //     [NSNumber numberWithInt: 2],AVNumberOfChannelsKey,    /*Not Supported*/
                                        
                                        [NSNumber numberWithInt:16],AVLinearPCMBitDepthKey,
                                        [NSNumber numberWithBool:NO],AVLinearPCMIsBigEndianKey,
                                        [NSNumber numberWithBool:NO],AVLinearPCMIsFloatKey,
                                        [NSNumber numberWithBool:NO],AVLinearPCMIsNonInterleaved,
                                        
                                        nil];
    
    
    AVAssetReaderTrackOutput* output = [[AVAssetReaderTrackOutput alloc] initWithTrack:songTrack outputSettings:outputSettingsDict];
    
    [reader addOutput:output];
    [output release];
    
    UInt32 sampleRate,channelCount;
    
    NSArray* formatDesc = songTrack.formatDescriptions;
    for(unsigned int i = 0; i < [formatDesc count]; ++i) {
        CMAudioFormatDescriptionRef item = (CMAudioFormatDescriptionRef)[formatDesc objectAtIndex:i];
        const AudioStreamBasicDescription* fmtDesc = CMAudioFormatDescriptionGetStreamBasicDescription (item);
        if(fmtDesc ) {
            
            sampleRate = fmtDesc->mSampleRate;
            channelCount = fmtDesc->mChannelsPerFrame;
            
            //    NSLog(@"channels:%u, bytes/packet: %u, sampleRate %f",fmtDesc->mChannelsPerFrame, fmtDesc->mBytesPerPacket,fmtDesc->mSampleRate);
        }
    }
    
    UInt32 bytesPerSample = 2 * channelCount;
    Float32 normalizeMax = noiseFloor;

    NSLog(@"normalizeMax = %f",normalizeMax);
    NSMutableData * fullSongData = [[NSMutableData alloc] init];
    [reader startReading];
    
    UInt64 totalBytes = 0;
    
    Float64 totalLeft = 0;
    Float64 totalRight = 0;
    Float32 sampleTally = 0;
    
    NSInteger samplesPerPixel = sampleRate / 50;
    
    while (reader.status == AVAssetReaderStatusReading){
        
        AVAssetReaderTrackOutput * trackOutput = (AVAssetReaderTrackOutput *)[reader.outputs objectAtIndex:0];
        CMSampleBufferRef sampleBufferRef = [trackOutput copyNextSampleBuffer];
        
        if (sampleBufferRef){
            CMBlockBufferRef blockBufferRef = CMSampleBufferGetDataBuffer(sampleBufferRef);
            
            size_t length = CMBlockBufferGetDataLength(blockBufferRef);
            totalBytes += length;
            
            NSAutoreleasePool *wader = [[NSAutoreleasePool alloc] init];
            
            NSMutableData * data = [NSMutableData dataWithLength:length];
            CMBlockBufferCopyDataBytes(blockBufferRef, 0, length, data.mutableBytes);
            
            SInt16 * samples = (SInt16 *) data.mutableBytes;
            int sampleCount = length / bytesPerSample;
            for (int i = 0; i < sampleCount ; i ++) {
                
                Float32 left = (Float32) *samples++;
                left = decibel(left);
                left = minMaxX(left,noiseFloor,0);
                
                totalLeft  += left;
                
                Float32 right;
                if (channelCount==2) {
                    right = (Float32) *samples++;
                    right = decibel(right);
                    right = minMaxX(right,noiseFloor,0);
                    
                    totalRight += right;
                }
                
                sampleTally++;
                
                if (sampleTally > samplesPerPixel) {
                    
                    left  = totalLeft / sampleTally;
                    if (left > normalizeMax) {
                        normalizeMax = left;
                    }
                    // NSLog(@"left average = %f, normalizeMax = %f",left,normalizeMax);
                    
                    [fullSongData appendBytes:&left length:sizeof(left)];
                    
                    if (channelCount==2) {
                        right = totalRight / sampleTally;
                        
                        
                        if (right > normalizeMax) {
                            normalizeMax = right;
                        }
                        
                        [fullSongData appendBytes:&right length:sizeof(right)];
                    }
                    
                    totalLeft   = 0;
                    totalRight  = 0;
                    sampleTally = 0;
                    
                }
            }
            
            [wader drain];
            
            CMSampleBufferInvalidate(sampleBufferRef);
            
            CFRelease(sampleBufferRef);
        }
    }
    
    UIImage *finalImage = nil;
    
    if (reader.status == AVAssetReaderStatusFailed || reader.status == AVAssetReaderStatusUnknown){
        // Something went wrong. Handle it.
        NSLog(@"[INFO] Image rendering failed");
    }
    
    if (reader.status == AVAssetReaderStatusCompleted){
        // You're done. It worked.
        
        finalImage = [self audioImageLogGraph:(Float32 *) fullSongData.bytes
                                    normalizeMax:normalizeMax
                                     sampleCount:fullSongData.length / (sizeof(Float32) * 2)
                                    channelCount:channelCount // Not working correctly. Works OK when forced to 2, even if source is mono (1).
                                     imageHeight:100];

    }
    
    [fullSongData release];
    [reader release];
    
    return finalImage;
}

@end
