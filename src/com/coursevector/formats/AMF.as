package com.coursevector.formats {
	
	import com.coursevector.minerva.PseudoThread;
	import com.coursevector.serialization.amf.AMF0;
	import com.coursevector.serialization.amf.AMF3;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.utils.ByteArray;
	
	import mx.managers.ISystemManager;
	
	public class AMF extends EventDispatcher {
		
		// AMF Version Constants
		public static const AMF0_VERSION:uint = 0;
		public static const AMF1_VERSION:uint = 1; // There is no AMF1 but FMS uses it for some reason, hence special casing.
		public static const AMF3_VERSION:uint = 3;
		
		protected var _data:Object;
		protected var _rawData:ByteArray = new ByteArray();
		protected var _amfVersion:uint;
		protected var _amfVersionInfo:String;
		protected var amf0:AMF0 = new AMF0();
		
		private var thread:PseudoThread;
		
		public function AMF() { }
		
		public function deserialize(data:ByteArray, sm:ISystemManager):void {
			_data = { };
			_data.headers = [];
			_data.bodies = [];
			_rawData = data;
			readHeader();
			readBody(sm);
		}
		
		public function serialize(sm:ISystemManager, data:Object, encode:uint = 3):void {
			switch(encode) {
				case AMF0_VERSION:
				case AMF1_VERSION:
				case AMF3_VERSION:
					break;
				default :
					encode = AMF3_VERSION;
			}
			
			_amfVersion = encode;
			
			switch(_amfVersion) {
				case AMF0_VERSION:
					_amfVersionInfo = "Flash Player 8 and Below";
					break;
				case AMF1_VERSION:
					_amfVersionInfo = "Flash Media Server";
					break;
				case AMF3_VERSION:
					_amfVersionInfo = "Flash Player 9+";
					break;
			}
			
			_data = data;
			_rawData.clear();
			amf0.reset();
			writeHeader();
			writeBody(sm);
		}
		
		public function get amfVersion():uint { return _amfVersion; }
		
		public function get amfVersionInfo():String { return _amfVersionInfo; }
		
		public function get data():Object { return _data; }
		
		public function get rawData():ByteArray { return _rawData; }
		
		/**
		 * Similar to AMF 0, AMF 3 object reference tables, object trait reference tables and string reference 
		 * tables must be reset each time a new context header or message is processed.
		 * 
		 * Note that Flash Player 9 will always set the second byte to 0×03, regardless of whether the message was sent in AMF0 or AMF3.
		 * 
		 * @param	data
		 */
		protected function readHeader():void {
			_amfVersion = _rawData.readUnsignedShort();
			switch(_amfVersion) {
				case AMF0_VERSION:
					_amfVersionInfo = "Flash Player 8 and Below";
					break;
				case AMF1_VERSION:
					_amfVersionInfo = "Flash Media Server";
					break;
				case AMF3_VERSION:
					_amfVersionInfo = "Flash Player 9+";
					break;
			}
			
			if (_amfVersion != AMF0_VERSION && _amfVersion != AMF3_VERSION) {
	            //Unsupported AMF version {version}.
	            throw new Error("Unsupported AMF version " + _amfVersion);     
	        }
			
			var numHeaders:uint = _rawData.readUnsignedShort(); //  find the total number of header elements return
			while (numHeaders--) {
				amf0.reset();
				var name:String = _rawData.readUTF();
				var required:Boolean = !!_rawData.readUnsignedByte(); // find the must understand flag
				var len:int = _rawData.readUnsignedInt(); // grab the length of the header element, -1 if unknown
				var data:* = amf0.readData(_rawData); // turn the element into real data
				
				_data.headers.push({ name:name, mustUnderstand:required, length:len, data:data }); // save the name/value into the headers array
			}
		}
		
		protected function readBody(sm:ISystemManager):void {
			var numBodies:uint = _rawData.readUnsignedShort(); // find the total number of body elements
			thread = new PseudoThread(sm, threadReadBody, { numBodies:numBodies });
			thread.addEventListener("threadComplete", threadCompleteHandler, false, 0, true);
		}
		
		protected function threadReadBody(obj:Object):Boolean {	
			if (obj.numBodies) {
				obj.numBodies--;
				amf0.reset();
				var targetURI:String = _rawData.readUTF(); // When the message holds a response from a remote endpoint, the target URI specifies which method on the local client (i.e. AMF request originator) should be invoked to handle the response.
				var responseURI:String = _rawData.readUTF(); // The response's target URI is set to the request's response URI with an '/onResult' suffix to denote a success or an '/onStatus' suffix to denote a failure.
				var len:int = _rawData.readUnsignedInt(); // grab the length of the body element, -1 if unknown
				var data:* = amf0.readData(_rawData); // turn the element into real data
				
				_data.bodies.push({ targetURI:targetURI, responseURI:responseURI, length:len, data:data }); // add the body element to the body object
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
			// AMF Encoding
			_rawData.writeShort(_amfVersion);
			//_rawData.writeUnsignedInt(_amfVersion);
			
			// Number of headers
			var l:int = _data.headers.length;
			_rawData.writeShort(l);
			
			// Write headers
			while(l--) {
				amf0.reset();
				_rawData.writeUTF(_data.headers[l].name); // name
				_rawData.writeBoolean(_data.headers[l].mustUnderstand); // required
				
				var ba:ByteArray = new ByteArray();
				if(_amfVersion == AMF3_VERSION) amf0.AVMPlus = true;
				amf0.writeData(ba, _data.headers[l].data);
				
				_rawData.writeUnsignedInt(ba.length); // length
				_rawData.writeBytes(ba); // data
			}
		}
		
		protected function writeBody(sm:ISystemManager):void {
			// Number of bodies
			var l:int = _data.bodies.length;
			_rawData.writeShort(l);
			
			thread = new PseudoThread(sm, threadWriteVariable, { l:l });
			thread.addEventListener("threadComplete", threadWriteCompleteHandler, false, 0, true);
		}
		
		protected function threadWriteCompleteHandler(event:Event):void {
			PseudoThread(event.currentTarget).removeEventListener("threadComplete", threadWriteCompleteHandler);
			thread = null;
			
			dispatchEvent(new Event(Event.COMPLETE));
		}
		
		protected function threadWriteVariable(obj:Object):Boolean {
			if (obj.l) {
				obj.l--;
				amf0.reset();
				_rawData.writeUTF(_data.bodies[obj.l].targetURI); // targetURI
				_rawData.writeUTF(_data.bodies[obj.l].responseURI); // responseURI
				
				var ba:ByteArray = new ByteArray();
				if(_amfVersion == AMF3_VERSION) amf0.AVMPlus = true;
				amf0.writeData(ba, _data.bodies[obj.l].data);
				
				_rawData.writeUnsignedInt(ba.length); // length
				_rawData.writeBytes(ba); // data
				return true;
			}
			
			return false;
		}
	}
}