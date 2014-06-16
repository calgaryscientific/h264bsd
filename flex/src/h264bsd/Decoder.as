package h264bsd
{
    import flash.display.BitmapData;
    import flash.events.EventDispatcher;
    import flash.filters.ColorMatrixFilter;
    import flash.geom.ColorTransform;
    import flash.geom.Matrix;
    import flash.geom.Point;
    import flash.geom.Rectangle;
    import flash.utils.ByteArray;
    import flash.utils.Endian;
    import flash.utils.getQualifiedClassName;
    
    import h264bsd_asm.CModule;
    
    [Event(name = "pictureReady", type = "pureweb.client.ui.H264DecoderEvent")]
    [Event(name = "headersReady", type = "pureweb.client.ui.H264DecoderEvent")]
    public class Decoder extends EventDispatcher
    {
        public static const RDY:int = 0;
        public static const PIC_RDY:int = 1;
        public static const HDRS_RDY:int = 2;
        public static const ERROR:int = 3;
        public static const PARAM_SET_ERROR:int = 4;
        public static const MEMALLOC_ERROR:int = 5;
        public static const NO_INPUT:int = 1024;
        
        private var _storagePtr:int = 0;
        private var _released:Boolean = false;
        private var _ready:Boolean = false;
        
        private var _h264bsdAlloc:int = 0;
        private var _h264bsdInit:int = 0;
        private var _h264bsdPicWidth:int = 0;
        private var _h264bsdPicHeight:int = 0;
        private var _h264bsdNextOutputPicture:int = 0;
        private var _h264bsdNextOutputPictureBGRA:int = 0;
        private var _h264bsdNextOutputPictureYCbCrA:int = 0;
        private var _h264bsdDecode:int = 0;
        private var _h264bsdShutdown:int = 0;
        private var _h264bsdFree:int = 0;
        private var _h264bsdCroppingParams:int = 0;
        
        private var _inputPtr:int = 0;
        private var _inputOffset:int = 0;
        private var _inputLength:int = 0;
        
        public function Decoder() {
            
            buildFunctionTable();
            initStorage();
            clearInputQueue();
            _ready = false;
            
        }
        
        public function release():void {
            if (_released) return;
            clearInputQueue();
            freeStorage();
            _released = true;
        }
        
        public function queueInput(data:ByteArray):void {
            if(data == null || data.bytesAvailable <= 0) return;
            
            if(_inputPtr != 0) {
                var combinedData:ByteArray = new ByteArray();
                CModule.readBytes(_inputPtr + _inputOffset, _inputLength - _inputOffset, combinedData);
                
                combinedData.writeBytes(data);
                combinedData.position= 0;
                data = combinedData;
            }
            
            _inputLength = data.bytesAvailable;
            _inputPtr = CModule.malloc(_inputLength);
            _inputOffset = 0;
            
            CModule.writeBytes(_inputPtr, _inputLength, data);
        }
        
        public function decode():int {
            if (_inputPtr == 0) return NO_INPUT;
            
            var bytesReadPtr:int = CModule.malloc(4);
            var dataPtr:int = _inputPtr + _inputOffset;
            var length:int = _inputLength - _inputOffset;
            
            var args:Vector.<int> = new <int>[_storagePtr, dataPtr, length, 0, bytesReadPtr];
            var result:int = CModule.callI(_h264bsdDecode, args);
            
            switch(result)
            {
                case Decoder.PIC_RDY:
                    dispatchEvent(new DecoderEvent(DecoderEvent.PICTURE_READY));
                    break;
                case Decoder.HDRS_RDY:
                    dispatchEvent(new DecoderEvent(DecoderEvent.HEADERS_READY));
                    break;
            }
            
            var bytesRead:int = CModule.read32(bytesReadPtr);
            _inputOffset += bytesRead;
            
            if(_inputOffset >= _inputLength) clearInputQueue();
            
            if (bytesReadPtr != 0) CModule.free(bytesReadPtr);
            
            return result;
        }
        
        public function getNextOutputPictureBytesBGRA():ByteArray {
            var picIdPtr:int = CModule.malloc(4);
            var isIdrPicPtr:int = CModule.malloc(4);
            var numErrMbsPtr:int = CModule.malloc(4);
            
            var bytesPtr:int = 0;
            var args:Vector.<int> = new <int>[_storagePtr, picIdPtr, isIdrPicPtr, numErrMbsPtr];
            bytesPtr = CModule.callI(_h264bsdNextOutputPictureBGRA, args);
            
            var bytes:ByteArray = new ByteArray();
            bytes.endian = Endian.LITTLE_ENDIAN;
            CModule.readBytes(bytesPtr, outputByteLengthRGBA, bytes);
            bytes.position = 0;
            
            if (picIdPtr != 0) CModule.free(picIdPtr);
            if (isIdrPicPtr != 0) CModule.free(isIdrPicPtr);
            if (numErrMbsPtr != 0) CModule.free(numErrMbsPtr);
            
            return bytes;
        }
        
        public function getNextOutputPictureBytesYCbCrA():ByteArray {
            var picIdPtr:int = CModule.malloc(4);
            var isIdrPicPtr:int = CModule.malloc(4);
            var numErrMbsPtr:int = CModule.malloc(4);
            
            var bytesPtr:int = 0;
            var args:Vector.<int> = new <int>[_storagePtr, picIdPtr, isIdrPicPtr, numErrMbsPtr];
            bytesPtr = CModule.callI(_h264bsdNextOutputPictureYCbCrA, args);
            
            var bytes:ByteArray = new ByteArray();
            bytes.endian = Endian.LITTLE_ENDIAN;
            CModule.readBytes(bytesPtr, outputByteLengthRGBA, bytes);
            bytes.position = 0;
            
            if (picIdPtr != 0) CModule.free(picIdPtr);
            if (isIdrPicPtr != 0) CModule.free(isIdrPicPtr);
            if (numErrMbsPtr != 0) CModule.free(numErrMbsPtr);
            
            return bytes;
        }
        
        public function getNextOutputPictureBytes():ByteArray {
            var picIdPtr:int = CModule.malloc(4);
            var isIdrPicPtr:int = CModule.malloc(4);
            var numErrMbsPtr:int = CModule.malloc(4);
            
            var bytesPtr:int = 0;
            var args:Vector.<int> = new <int>[_storagePtr, picIdPtr, isIdrPicPtr, numErrMbsPtr];
            bytesPtr = CModule.callI(_h264bsdNextOutputPicture, args);
            
            var bytes:ByteArray = new ByteArray();
            bytes.endian = Endian.LITTLE_ENDIAN;
            CModule.readBytes(bytesPtr, outputByteLength, bytes);
            bytes.position = 0;
            
            if (picIdPtr != 0) CModule.free(picIdPtr);
            if (isIdrPicPtr != 0) CModule.free(isIdrPicPtr);
            if (numErrMbsPtr != 0) CModule.free(numErrMbsPtr);
            
            return bytes;
        }
        
        public function drawNextOutputPicture(target:BitmapData, transform:Matrix = null):void
        {
            if(target == null) return;
            
            var outputPictureBytes:ByteArray = getNextOutputPictureBytesYCbCrA();
            var cinfo:CroppingInfo = getCroppingInfo();
            
            var width:int = cinfo.uncroppedWidth;
            var height:int = cinfo.uncroppedHeight;
            
            var outputPicture:BitmapData = new BitmapData(width, height);
            outputPicture.setPixels(new Rectangle(0,0, width, height), outputPictureBytes);
            
            var bt601Filter:ColorMatrixFilter = new ColorMatrixFilter([
                1.596, 0, 1.164, 0, -222.912,
                -.813, -.392, 1.164, 0, 135.616,
                0, 2.017, 1.164, 0, -276.8,
                0, 0, 0, 1, 0
            ]);
            
            
            var tempData:BitmapData = new BitmapData(cinfo.width, cinfo.height);
            tempData.lock();
            target.lock();
            
            // Cropped and color converted
            tempData.applyFilter( outputPicture, new Rectangle(0, 0, cinfo.width, cinfo.height), new Point(0, 0), bt601Filter);
            
            // Translated and scaled
            target.draw(tempData, transform, null, null, null, true);
            
            tempData.unlock();
            target.unlock();   
			
			outputPicture.dispose();
			tempData.dispose();
        }

        private function get outputByteLength():int { 
            return outputWidth * outputHeight * 3 / 2;
        }
        
        private function get outputByteLengthRGBA():int { 
            return outputWidth * outputHeight * 4;
        }
        
        private function get outputWidth():int {
            var widthMB:int = CModule.callI(_h264bsdPicWidth, new <int>[_storagePtr]);
            return widthMB * 16;
        }
        
        private function get outputHeight():int {
            var heightMB:int = CModule.callI(_h264bsdPicHeight, new <int>[_storagePtr]);
            return heightMB * 16;
        }
        
        public function getCroppingInfo():CroppingInfo {
            var croppingFlagPtr:int = CModule.malloc(4);
            var leftOffsetPtr:int = CModule.malloc(4);
            var widthPtr:int = CModule.malloc(4);
            var topOffsetPtr:int = CModule.malloc(4);
            var heightPtr:int = CModule.malloc(4);
            
            var args:Vector.<int> = new <int>[_storagePtr, croppingFlagPtr, leftOffsetPtr, widthPtr, topOffsetPtr, heightPtr];
            CModule.callI(_h264bsdCroppingParams, args);
            
            // XXX: Cropping info appears to be broken
            var result:CroppingInfo = new CroppingInfo(outputWidth, outputHeight, CModule.read32(widthPtr), CModule.read32(heightPtr), CModule.read32(topOffsetPtr), CModule.read32(leftOffsetPtr));
            
            CModule.free(croppingFlagPtr);
            CModule.free(leftOffsetPtr);
            CModule.free(widthPtr);
            CModule.free(topOffsetPtr);
            CModule.free(heightPtr);
            
            return result;
        }
        
        private function buildFunctionTable():void {
            _h264bsdAlloc = CModule.getPublicSymbol("h264bsdAlloc");
            _h264bsdInit = CModule.getPublicSymbol("h264bsdInit");
            _h264bsdPicWidth = CModule.getPublicSymbol("h264bsdPicWidth");
            _h264bsdPicHeight = CModule.getPublicSymbol("h264bsdPicHeight");
            _h264bsdNextOutputPicture = CModule.getPublicSymbol("h264bsdNextOutputPicture");
            _h264bsdNextOutputPictureBGRA = CModule.getPublicSymbol("h264bsdNextOutputPictureBGRA");
            _h264bsdNextOutputPictureYCbCrA = CModule.getPublicSymbol("h264bsdNextOutputPictureYCbCrA");
            _h264bsdDecode = CModule.getPublicSymbol("h264bsdDecode");
            _h264bsdShutdown = CModule.getPublicSymbol("h264bsdShutdown");
            _h264bsdFree = CModule.getPublicSymbol("h264bsdFree");
            _h264bsdCroppingParams = CModule.getPublicSymbol("h264bsdCroppingParams");
            
            if (_h264bsdAlloc == 0 ||
                _h264bsdInit == 0 ||
                _h264bsdPicWidth == 0 ||
                _h264bsdPicHeight == 0 ||
                _h264bsdNextOutputPicture == 0 ||
                _h264bsdDecode == 0 ||
                _h264bsdShutdown == 0 ||
                _h264bsdFree == 0 ||
                _h264bsdCroppingParams == 0 || 
                _h264bsdNextOutputPictureBGRA == 0 ||
                _h264bsdNextOutputPictureYCbCrA == 0) {
                throw new Error("One or more missing entries in h264bsd function table.");
            }
        }
        
        private function initStorage():void {
            if(_storagePtr != 0) return;
            _storagePtr = CModule.callI(_h264bsdAlloc, new <int>[]);
            CModule.callI(_h264bsdInit, new <int>[_storagePtr, 0]);
        }
        
        private function freeStorage():void {
            if(_storagePtr == 0) return;
            
            CModule.callI(_h264bsdShutdown, new <int>[this._storagePtr]);
            CModule.callI(_h264bsdFree, new <int>[this._storagePtr]);
        }
        
        private function clearInputQueue():void {
            if(_inputPtr == 0) return;
            CModule.free(_inputPtr);
            _inputPtr = 0;
            _inputOffset = 0;
            _inputLength = 0;
        }
    }    
}
