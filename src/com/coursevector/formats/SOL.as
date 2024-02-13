package com.coursevector.formats {
	
	import com.coursevector.minerva.PseudoThread;
	import com.coursevector.serialization.amf.AMF0;
	import com.coursevector.serialization.amf.AMF3;
	
	import flash.errors.EOFError;
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.net.ObjectEncoding;
	import flash.utils.ByteArray;
	
	import mx.managers.ISystemManager;
	
	public class SOL extends EventDispatcher {
		
		protected var _data:Object;
		protected var _rawData:ByteArray = new ByteArray();
		protected var _amfVersion:uint;
		protected var _fileName:String;
		protected var amf0:AMF0 = new AMF0();
		protected var amf3:AMF3 = new AMF3();
		
		private var thread:PseudoThread;
		
		/**
		 * Helper variable for creating the header
		 */
		protected var _bodyData:ByteArray = new ByteArray();
		
		public function SOL() {
			amf3.addEventListener(ErrorEvent.ERROR, errorHandler);
		}
		
		public function deserialize(data:ByteArray, sm:ISystemManager):void {
			_data = { };
			_rawData = data;
			amf3.reset();
			amf0.reset();
			readHeader(sm);
			//readBody(sm);
		}
		
		public function serialize(sm:ISystemManager, fileName:String, data:Object, encode:uint = 3):void {
			_fileName = fileName;
			_amfVersion = encode;
			_data = data;
			_rawData.clear();
			_bodyData.clear();
			amf3.reset();
			amf0.reset();
			writeHeader();
			writeBody(sm);
			//writeHeader2();
		}
		
		public function get amfVersion():uint { return _amfVersion; }
		
		public function get fileName():String { return _fileName; }
		
		public function get data():Object { return _data; }
		
		public function get rawData():ByteArray { return _rawData; }
		
		protected function readHeader(sm:ISystemManager):void {
			var nLenFile:uint = _rawData.bytesAvailable;
			
			// Unknown header 0x00 0xBF
			_rawData.readShort();
			
			// Length of the rest of the file (filesize - 6)
			var nLenData:int = _rawData.readUnsignedInt();
			
			if (nLenFile != nLenData + 6) {
				//throw new Error('Data Length Mismatch');
				//return;
				dispatchEvent(new ErrorEvent(ErrorEvent.ERROR, false, false, "Data Length Mismatch\nFile Length:" + nLenFile + " Data Length:" + (nLenData+6)));
			}
			
			// Signature, 'TCSO'
			_rawData.readUTFBytes(4);
			
			// Unknown, 6 bytes long 0x00 0x04 0x00 0x00 0x00 0x00 0x00
			_rawData.readUTFBytes(6);
			
			// Read SOL Name
			_fileName = _rawData.readUTFBytes(_rawData.readUnsignedShort());
			
			// AMF Encoding
			_amfVersion = _rawData.readUnsignedInt();
			
			if(_amfVersion === ObjectEncoding.AMF0 || _amfVersion === ObjectEncoding.AMF3) {
				if(_fileName == "undefined") _fileName = "[SOL Name not Set]";
				readBody(sm);
			} else {
				_fileName = "[Not yet supported sol format]";
			}
		}
		
		protected function readBody(sm:ISystemManager):void {
			thread = new PseudoThread(sm, threadReadVariable, { });
			thread.addEventListener("threadComplete", threadCompleteHandler, false, 0, true);
		}
		
		protected function threadReadVariable(obj:Object):Boolean {
			if (_rawData.bytesAvailable > 1) {		
				try {
					readVariable();
				} catch(e:EOFError) {
					trace(e.message);
					return false;
				}
				return true;
			}
			
			return false;
		}
		
		protected function threadCompleteHandler(event:Event):void {
			PseudoThread(event.currentTarget).removeEventListener("threadComplete", threadCompleteHandler);
			thread = null;
			
			dispatchEvent(new Event(Event.COMPLETE));
		}
		
		protected function writeHeader():void {
			// A lot of the header information is written to the body first
			// This is so we get an accurate length for the header
			
			// Signature, 'TCSO'
			_bodyData.writeUTFBytes("TCSO");
			
			// Unknown
			_bodyData.writeByte(0x00);
			_bodyData.writeByte(0x04);
			_bodyData.writeByte(0x00);
			_bodyData.writeByte(0x00);
			_bodyData.writeByte(0x00);
			_bodyData.writeByte(0x00);
			
			// Filename
			_bodyData.writeUTF(_fileName);
			
			// AMF Encoding
			_bodyData.writeUnsignedInt(_amfVersion);
		}
		
		protected function writeHeader2():void {
			// Unknown header 0x00 0xBF
			_rawData.writeByte(0x00);
			_rawData.writeByte(0xBF);
			
			// Length of the rest of the file (filesize - 6)
			_rawData.writeUnsignedInt(_bodyData.length);
			
			// Data
			_rawData.writeBytes(_bodyData);
		}
		
		protected function writeBody(sm:ISystemManager):void {
			var arr:Array = [];
			for (var key:String in _data) {
				arr.push(key);
			}
			
			thread = new PseudoThread(sm, threadWriteVariable, { keys:arr });
			thread.addEventListener("threadComplete", threadWriteCompleteHandler, false, 0, true);
		}
		
		protected function threadWriteCompleteHandler(event:Event):void {
			PseudoThread(event.currentTarget).removeEventListener("threadComplete", threadWriteCompleteHandler);
			thread = null;
			
			writeHeader2();
			
			dispatchEvent(new Event(Event.COMPLETE));
		}
		
		protected function threadWriteVariable(obj:Object):Boolean {
			if (obj.keys.length) {
				var key:String = obj.keys.shift() as String;
			//for (var key:String in _data) {
				if(_amfVersion == ObjectEncoding.AMF3) {
					amf3.writeString(_bodyData, key);
					amf3.writeData(_bodyData, _data[key]);
				} else {
					_bodyData.writeUTF(key);
					amf0.writeData(_bodyData, _data[key]);
				}
				
				_bodyData.writeByte(0); // Ending byte
				return true;
			}
			
			return false;
		}
		
		protected function readVariable():void {
			var varName:String = "";
			var varVal:*;
			
			if (_amfVersion == ObjectEncoding.AMF3) {
				varName = amf3.readString(_rawData);
				varVal = amf3.readData(_rawData);
			} else {
				varName = _rawData.readUTF();
				varVal = amf0.readData(_rawData);
			}
			_rawData.readByte(); // Ending byte
			
			_data[varName] = varVal;
		}
		
		private function errorHandler(e:ErrorEvent):void {
			dispatchEvent(e.clone());
		}
	}
}