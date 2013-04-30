
#include "ofQTKitPlayer.h"

#include "Poco/String.h"

//--------------------------------------------------------------------
ofQTKitPlayer::ofQTKitPlayer() {
	moviePlayer = NULL;
	bNewFrame = false;
    bPaused = true;
	duration = 0.0f;
    speed = 1.0f;
	// default this to true so the player update behavior matches ofQuicktimePlayer
	bSynchronousSeek = true;
    
    bInitialized = false;
    
    pixelFormat = OF_PIXELS_RGB;
    currentLoopState = OF_LOOP_NORMAL;
}

//--------------------------------------------------------------------
ofQTKitPlayer::~ofQTKitPlayer() {
	close();	
}

//--------------------------------------------------------------------
bool ofQTKitPlayer::loadMovie(string path){
	return loadMovie(path, OF_QTKIT_DECODE_PIXELS_ONLY);
}

//--------------------------------------------------------------------
bool ofQTKitPlayer::loadMovie(string movieFilePath, ofQTKitDecodeMode mode) {
    return loadMovie(movieFilePath, mode, false);
}

bool ofQTKitPlayer::loadMovie(string movieFilePath, ofQTKitDecodeMode mode, bool async) {
	if(mode != OF_QTKIT_DECODE_PIXELS_ONLY && mode != OF_QTKIT_DECODE_TEXTURE_ONLY && mode != OF_QTKIT_DECODE_PIXELS_AND_TEXTURE){
		ofLogError("ofQTKitPlayer") << "Invalid ofQTKitDecodeMode mode specified while loading movie.";
		return false;
	}
	
	if(isLoaded()){
		close(); //auto released 
	}
    
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    
    decodeMode = mode;
	bool useTexture = (mode == OF_QTKIT_DECODE_TEXTURE_ONLY || mode == OF_QTKIT_DECODE_PIXELS_AND_TEXTURE);
	bool usePixels  = (mode == OF_QTKIT_DECODE_PIXELS_ONLY  || mode == OF_QTKIT_DECODE_PIXELS_AND_TEXTURE);
	bool useAlpha = (pixelFormat == OF_PIXELS_RGBA);

    bool isURL = false;
	
    if (Poco::icompare(movieFilePath.substr(0,7), "http://")  == 0 ||
        Poco::icompare(movieFilePath.substr(0,8), "https://") == 0 ||
        Poco::icompare(movieFilePath.substr(0,7), "rtsp://")  == 0) {
        isURL = true;
    }
    else {
        movieFilePath = ofToDataPath(movieFilePath, false);
    }

	moviePlayer = [[QTKitMovieRenderer alloc] init];
	BOOL success = [moviePlayer  loadMovie:[NSString
                                            stringWithCString:movieFilePath.c_str()
                                            encoding:NSUTF8StringEncoding]
                            synchronously:!async
								pathIsURL:isURL
							 allowTexture:useTexture 
							  allowPixels:usePixels
                               allowAlpha:useAlpha];
	if(success){
		moviePlayer.synchronousSeek = bSynchronousSeek;
        reallocatePixels();
        moviePath = movieFilePath;
		//duration = moviePlayer.duration;

        setLoopState(currentLoopState);
        
        //setSpeed(1.0f);
		//firstFrame(); //will load the first frame
	}
	else {
		ofLogError("ofQTKitPlayer") << "Loading file " << movieFilePath << " failed.";
		[moviePlayer release];
		moviePlayer = NULL;
	}
	
    //bInitialized = true;
    
	[pool release];
	
	return success;
}

//--------------------------------------------------------------------
bool ofQTKitPlayer::loadMovieAsync(string path){
	return loadMovieAsync(path, OF_QTKIT_DECODE_PIXELS_ONLY);
}

//--------------------------------------------------------------------
bool ofQTKitPlayer::loadMovieAsync(string movieFilePath, ofQTKitDecodeMode mode) {
	if(mode != OF_QTKIT_DECODE_PIXELS_ONLY && mode != OF_QTKIT_DECODE_TEXTURE_ONLY && mode != OF_QTKIT_DECODE_PIXELS_AND_TEXTURE){
		ofLogError("ofQTKitPlayer") << "Invalid ofQTKitDecodeMode mode specified while loading movie.";
		return false;
	}
	
	if(isLoaded()){
		close(); //auto released
	}
    
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    
    decodeMode = mode;
	bool useTexture = (mode == OF_QTKIT_DECODE_TEXTURE_ONLY || mode == OF_QTKIT_DECODE_PIXELS_AND_TEXTURE);
	bool usePixels  = (mode == OF_QTKIT_DECODE_PIXELS_ONLY  || mode == OF_QTKIT_DECODE_PIXELS_AND_TEXTURE);
	bool useAlpha = (pixelFormat == OF_PIXELS_RGBA);
    
    bool isURL = false;
	
    if (Poco::icompare(movieFilePath.substr(0,7), "http://")  == 0 ||
        Poco::icompare(movieFilePath.substr(0,8), "https://") == 0 ||
        Poco::icompare(movieFilePath.substr(0,7), "rtsp://")  == 0) {
        isURL = true;
    }
    else {
        movieFilePath = ofToDataPath(movieFilePath, false);
    }
    
    moviePath = movieFilePath;
	moviePlayer = [[QTKitMovieRenderer alloc] init];
    
    // SK: Everything below needs to be done async/with a callback
    //NSLog(@"Loading Movie");
    [moviePlayer prepareForLoadAsync];
    
    bInitialized = false;
    
    //NSLog(@"Starting async movie thread...");
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{

        BOOL success = [moviePlayer loadMovieAsync:[NSString stringWithCString:movieFilePath.c_str() encoding:NSUTF8StringEncoding]
                                    pathIsURL:isURL
                                 allowTexture:useTexture
                                  allowPixels:usePixels
                                   allowAlpha:useAlpha];
        
        //if(success) NSLog(@"Movie Loaded");
        /*
        // The following is moved to update() to avoid problems with this c++ object being
        // deleted while the aync loading is happening
         
        dispatch_async(dispatch_get_main_queue(), ^{
            if(success){
                moviePlayer.synchronousSeek = bSynchronousSeek;
                reallocatePixels();
                moviePath = movieFilePath;
                duration = moviePlayer.duration;
                
                setLoopState(currentLoopState);
                setSpeed(1.0f);
                firstFrame(); //will load the first frame
            }
            else {
                ofLogError("ofQTKitPlayer") << "Loading file " << movieFilePath << " failed.";
                [moviePlayer release];
                moviePlayer = NULL;
            }
            
            
            NSLog(@"Textures allocated");
        });
        */
    });

    [pool release];
	return YES;
}


//--------------------------------------------------------------------
void ofQTKitPlayer::closeMovie() {
	close();
}

//--------------------------------------------------------------------
bool ofQTKitPlayer::isLoaded() {
	return moviePlayer != NULL && [moviePlayer isLoaded];
}

bool ofQTKitPlayer::isLoading() {
    return [moviePlayer isLoading];
}
bool ofQTKitPlayer::errorLoading() {
    return [moviePlayer errorLoading];
}

//--------------------------------------------------------------------
void ofQTKitPlayer::close() {
	
	if(isLoaded()){
        NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
		[moviePlayer release];
		moviePlayer = NULL;
        [pool release];
	}
	
	pixels.clear();
	duration = 0;
}

//--------------------------------------------------------------------
void ofQTKitPlayer::setPaused(bool _bPaused){
    if(!isLoaded()) return;

    bPaused = _bPaused;
    
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

	if (bPaused) {
		[moviePlayer setRate:0.0f];
	} else {
		[moviePlayer setRate:speed];
	}

	[pool release];
    
}

//--------------------------------------------------------------------
bool ofQTKitPlayer::isPaused() {
	return bPaused;
}

//--------------------------------------------------------------------
void ofQTKitPlayer::stop() {
	setPaused(true);
}

//--------------------------------------------------------------------
bool ofQTKitPlayer::isPlaying(){
    if(!isLoaded()) return false;

	return !moviePlayer.isFinished && !isPaused(); 
}

//--------------------------------------------------------------------
void ofQTKitPlayer::firstFrame(){
	if(!isLoaded()) return;

    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    [moviePlayer gotoBeginning];
	bHavePixelsChanged = bNewFrame = bSynchronousSeek;
    [pool release];
}

//--------------------------------------------------------------------
void ofQTKitPlayer::nextFrame(){
    if(!isLoaded()) return;

    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    [moviePlayer stepForward];
	bHavePixelsChanged = bNewFrame = bSynchronousSeek;
    [pool release];
}

//--------------------------------------------------------------------
void ofQTKitPlayer::previousFrame(){
    if(!isLoaded()) return;

    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    [moviePlayer stepBackward];
	bHavePixelsChanged = bNewFrame = bSynchronousSeek;
    [pool release];
    
}

//--------------------------------------------------------------------
void ofQTKitPlayer::setSpeed(float rate){
	if(!isLoaded()) return;

    speed = rate;

    if(isPlaying()) {
        NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
        [moviePlayer setRate:rate];
        [pool release];
    }
}

//--------------------------------------------------------------------
void ofQTKitPlayer::play(){
	if(!isLoaded()) return;
    
    if(isPaused()) {
        NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
        [moviePlayer setRate:speed];
        [pool release];
    }
}

//--------------------------------------------------------------------
void ofQTKitPlayer::idleMovie() {
	update();
}

//--------------------------------------------------------------------
void ofQTKitPlayer::update() {
	if(moviePlayer == NULL || [moviePlayer settingRate])
        return;

  	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    
    if(bInitialized) {
        // SK: Manually loop if the loop state couldn't be set for some reason (async loading)
        if(currentLoopState == OF_LOOP_NORMAL && currentLoopState != getLoopState() && [moviePlayer frame] >= [moviePlayer frameCount]) {
            firstFrame();
        }
        bNewFrame = [moviePlayer update];
        if(bNewFrame) {
            bHavePixelsChanged = true;
        }
    }
    else if([moviePlayer isReady]) {
        // Run only once after asynchronous loading is complete
        //NSLog(@"Reallocating pixels.");
        reallocatePixels();
        //NSLog(@"Pixels reallocated.");
        duration = moviePlayer.duration;
        
        setLoopState(currentLoopState);
        //setSpeed(1.0f);
        firstFrame(); //will load the first frame

        ofVideoReadyEventArgs readyEvent;
        readyEvent.player = this;
        ofNotifyEvent(videoReadyEvent, readyEvent, this);
        
        bInitialized = true;
        
        //NSLog(@"Textures allocated");
    }

    [pool release];
}

//--------------------------------------------------------------------
bool ofQTKitPlayer::isFrameNew() {
	return bNewFrame;
}
		
//--------------------------------------------------------------------
void ofQTKitPlayer::bind() {
	if(!isLoaded() || !moviePlayer.useTexture) return;
	updateTexture();
	tex.bind();
}

//--------------------------------------------------------------------
void ofQTKitPlayer::unbind(){
	if(!isLoaded() || !moviePlayer.useTexture) return;
	tex.unbind();
}

//--------------------------------------------------------------------
void ofQTKitPlayer::draw(float x, float y) {
	draw(x,y, moviePlayer.movieSize.width, moviePlayer.movieSize.height);
}

//--------------------------------------------------------------------
void ofQTKitPlayer::draw(float x, float y, float w, float h) {
	updateTexture();
	tex.draw(x,y,w,h);	
}

//--------------------------------------------------------------------
ofPixelsRef	ofQTKitPlayer::getPixelsRef(){
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

	if(isLoaded() && bInitialized && moviePlayer.usePixels) {
	   //don't get the pixels every frame if it hasn't updated
	   if(bHavePixelsChanged){
		   [moviePlayer pixels:pixels.getPixels()];
		   bHavePixelsChanged = false;
	   }
	}
    else{
        ofLogError("ofQTKitPlayer") << "Returning pixels that may be unallocated. Make sure to initialize the video player before calling getPixelsRef.";
    }

    [pool release];
	return pixels;	   
}

//--------------------------------------------------------------------
unsigned char* ofQTKitPlayer::getPixels() {
	return getPixelsRef().getPixels();
}

//--------------------------------------------------------------------
ofTexture* ofQTKitPlayer::getTexture() {
    ofTexture* texPtr = NULL;
	if(moviePlayer.textureAllocated){
		updateTexture();
        return &tex;
	} else {
        return NULL;
    }
}

//--------------------------------------------------------------------
void ofQTKitPlayer::setPosition(float pct) {
	if(!isLoaded()) return;

	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    [moviePlayer setPosition:pct];
	[pool release];
    
    bHavePixelsChanged = bNewFrame = bSynchronousSeek;
}

//--------------------------------------------------------------------
void ofQTKitPlayer::setVolume(float volume) {
	if(!isLoaded()) return;
	
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	[moviePlayer setVolume:volume];
	[pool release];
}

//--------------------------------------------------------------------
void ofQTKitPlayer::setBalance(float balance) {
	if(!isLoaded()) return;
	
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	[moviePlayer setBalance:balance];
	[pool release];
}

//--------------------------------------------------------------------
void ofQTKitPlayer::setFrame(int frame) {
	if(!isLoaded()) return;
    
    frame %= [moviePlayer frameCount];
    
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    [moviePlayer setFrame:frame];
	[pool release];

	bHavePixelsChanged = bNewFrame = bSynchronousSeek;
}

//--------------------------------------------------------------------
int ofQTKitPlayer::getCurrentFrame() {
	if(!isLoaded()) return 0;
    return [moviePlayer frame];
}

//--------------------------------------------------------------------
int ofQTKitPlayer::getTotalNumFrames() {
	if(!isLoaded()) return 0;
	return [moviePlayer frameCount];
}

//--------------------------------------------------------------------
void ofQTKitPlayer::setLoopState(ofLoopType state) {
	if(!isLoaded()) return;
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

    currentLoopState = state;

	if(state == OF_LOOP_NONE){
        [moviePlayer setLoops:false];
        [moviePlayer setPalindrome:false];
	}
	else if(state == OF_LOOP_NORMAL){
        [moviePlayer setLoops:true];
        [moviePlayer setPalindrome:false];
	}
	else if(state == OF_LOOP_PALINDROME) {
        [moviePlayer setLoops:false];
        [moviePlayer setPalindrome:true];
    }
    
    [pool release];
}

//--------------------------------------------------------------------
ofLoopType ofQTKitPlayer::getLoopState(){
	if(!isLoaded()) return OF_LOOP_NONE;
	
	ofLoopType state = OF_LOOP_NONE;
	
    if(![moviePlayer loops] && ![moviePlayer palindrome]){
		state = OF_LOOP_NONE;
	}
	else if([moviePlayer loops] && ![moviePlayer palindrome]){
		state =  OF_LOOP_NORMAL;
	}
	else if([moviePlayer loops] && [moviePlayer palindrome]) {
    	state = OF_LOOP_PALINDROME;
	}
	else{
		ofLogError("ofQTKitPlayer") << "Invalid loop state " << state << ".";
	}
	
	return state;
}

//--------------------------------------------------------------------
float ofQTKitPlayer::getSpeed(){
	return speed;
}

//--------------------------------------------------------------------
float ofQTKitPlayer::getDuration(){
	return duration;
}

//--------------------------------------------------------------------
float ofQTKitPlayer::getPositionInSeconds(){
	return getPosition() * duration;
}

//--------------------------------------------------------------------
float ofQTKitPlayer::getPosition(){
	if(!isLoaded()) return 0;
	return [moviePlayer position];
}

//--------------------------------------------------------------------
bool ofQTKitPlayer::getIsMovieDone(){
	if(!isLoaded()) return false;
	return [moviePlayer isFinished];
}

//--------------------------------------------------------------------
float ofQTKitPlayer::getWidth() {
    return [moviePlayer movieSize].width;
}

//--------------------------------------------------------------------
float ofQTKitPlayer::getHeight() {
    return [moviePlayer movieSize].height;
}

//--------------------------------------------------------------------
bool ofQTKitPlayer::setPixelFormat(ofPixelFormat newPixelFormat){
    if(newPixelFormat != OF_PIXELS_RGB && newPixelFormat != OF_PIXELS_RGBA) {
        ofLogWarning("ofQTKitPlayer") << "Pixel format " << newPixelFormat << " is not supported.";
        return false;
    }

    if(newPixelFormat != pixelFormat){
        pixelFormat = newPixelFormat;
        // If we already have a movie loaded we need to reload
        // the movie with the new settings correctly allocated.
        if(isLoaded()){
            loadMovie(moviePath, decodeMode);
        }
    }	
	return true;
}

//--------------------------------------------------------------------
ofPixelFormat ofQTKitPlayer::getPixelFormat(){
	return pixelFormat;
}

//--------------------------------------------------------------------
ofQTKitDecodeMode ofQTKitPlayer::getDecodeMode(){
    return decodeMode;
}

//--------------------------------------------------------------------
void ofQTKitPlayer::setSynchronousSeeking(bool synchronous){
	bSynchronousSeek = synchronous;
    if(isLoaded()){
        moviePlayer.synchronousSeek = synchronous;
    }
}

//--------------------------------------------------------------------
bool ofQTKitPlayer::getSynchronousSeeking(){
	return 	bSynchronousSeek;
}

//--------------------------------------------------------------------
void ofQTKitPlayer::reallocatePixels(){
    if(pixelFormat == OF_PIXELS_RGBA){
        pixels.allocate(getWidth(), getHeight(), OF_IMAGE_COLOR_ALPHA);
    } else {
        pixels.allocate(getWidth(), getHeight(), OF_IMAGE_COLOR);
    }
}

//--------------------------------------------------------------------
void ofQTKitPlayer::updateTexture(){
	if(moviePlayer.textureAllocated){
	   		
		tex.setUseExternalTextureID(moviePlayer.textureID); 
		ofTextureData& data = tex.getTextureData();
		data.textureTarget = moviePlayer.textureTarget;
		data.width = getWidth();
		data.height = getHeight();
		data.tex_w = getWidth();
		data.tex_h = getHeight();
		data.tex_t = getWidth();
		data.tex_u = getHeight();
	}
}

