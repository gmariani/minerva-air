/* 
	AMF0 parser, reads and writes AMF0 encoded data
    Copyright (C) 2009  Gabriel Mariani

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
 
/*
uint8 - BYTE - readUnsignedByte
int8 - CHAR - readByte
uint16 - USHORT - readUnsignedShort
int16 - SHORT - readShort
uint32 - ULONG - readUnsignedInt
int32 - LONG - readInt

readBoolean : moves position by 1
readByte : moves position by 1
readDouble : moves position by 8
readFloat : moves position by 4
readInt : moves position by 4
readMultiByte : Reads a multibyte string of specified length from the file stream, byte stream
readShort : moves position by 2
readUnsignedByte : moves position by 1
readUnsignedInt : moves position by 4
readUnsignedShort : moves position by 2
readUTF : reads based on assumed prefix of string length
readUTFBytes : moves specified amount

http://opensource.adobe.com/svn/opensource/blazeds/trunk/modules/core/src/flex/messaging/io/amf/Amf0Output.java
*/

package com.coursevector.serialization.amf {
	
	import flash.utils.ByteArray;
	import flash.utils.describeType;
	import flash.utils.Dictionary;
	import flash.xml.XMLDocument;
	
	public class AMF0 {
		
		public const VERSION:String = "2.0.0";
		
		// AMF marker constants
		protected const NUMBER_TYPE:int = 0;
		protected const BOOLEAN_TYPE:int = 1;
		protected const STRING_TYPE:int = 2;
		protected const OBJECT_TYPE:int = 3;
		protected const MOVIECLIP_TYPE:int = 4; // reserved, not supported
		protected const NULL_TYPE:int = 5;
		protected const UNDEFINED_TYPE:int = 6;
		protected const REFERENCE_TYPE:int = 7;
		protected const ECMA_ARRAY_TYPE:int = 8; // associative
		protected const OBJECT_END_TYPE:int = 9;
		protected const STRICT_ARRAY_TYPE:int = 10;
		protected const DATE_TYPE:int = 11;
		protected const LONG_STRING_TYPE:int = 12; // string.length > 2^16
		protected const UNSUPPORTED_TYPE:int = 13;
		protected const RECORD_SET_TYPE:int = 14; // reserved, not supported
		protected const XML_OBJECT_TYPE:int = 15;
		protected const TYPED_OBJECT_TYPE:int = 16;
		protected const AVMPLUS_OBJECT_TYPE:int = 17;
		
		/**
		 * The maximum number of cached objects
		 */
		protected const MAX_STORED_OBJECTS:int = 1024;
		
		protected const EMPTY_STRING:String = "";
		
		/**
		 * The actual object cache used to store references
		 */
		protected var readObjectCache:Array = new Array(); // Length 64
		
		protected var writeObjectCache:Array;
		
		/**
		 * The raw binary data
		 */
		protected var _rawData:ByteArray;
		
		/**
		 * The decoded data
		 */
		protected var _data:*;
		
		/**
	     * AVM+ Encoding
	     */
		protected var _avmPlus:Boolean = false;
		
		/**
		 * Unfortunately the Flash Player starts AMF 3 messages off with the legacy
		 * AMF 0 format and uses a type, AmfTypes.kAvmPlusObjectType, to indicate
		 * that the next object in the stream is to be deserialized differently. The
		 * original hope was for two independent encoding versions... but for now
		 * we just keep a reference to objectInput here.
		 * @exclude
		 */
		protected var amf3:AMF3;
		
		public function AMF0():void { }
		
		public function get data():* { return _data; }
		
		public function get rawData():ByteArray { return _rawData; }
		
		/**
	     * Set to true if the AMF0 stream should switch to use AMF3 on encountering
	     * the first complex Object during serialization.
	     */
		public function set AVMPlus(value:Boolean):void {
			_avmPlus = value;
		}
		
		public function deserialize(data:ByteArray):void {
			reset();
			_rawData = data;
			_data = readData(_rawData);
		}
		
		/**
	     * Serialize an Object using AMF 0.
	     */
		public function serialize(data:*):void {
			reset();
			_data = data;
			_rawData = new ByteArray();
			writeData(_rawData, data);
		}
		
		/**
	     * Reset all object reference information allowing the class to be used to
	     * write a "new" data structure.
	     */
		public function reset():void {
			readObjectCache = new Array();
			
			writeObjectCache = null;
			
			if(amf3 != null) amf3.reset();
		}
		
		public function readData(ba:ByteArray, type:int = -1):* {
			if(type == -1) type = ba.readByte();
			switch(type) {
				case NUMBER_TYPE : return readNumber(ba);
				case BOOLEAN_TYPE : return readBoolean(ba);
				case STRING_TYPE : return readString(ba);
				case OBJECT_TYPE : return readObject(ba);
				//case MOVIECLIP_TYPE : return null;
				case NULL_TYPE : return null;
				case UNDEFINED_TYPE : return readUndefined(ba);
				case REFERENCE_TYPE : return getObjectReference(ba);
				case ECMA_ARRAY_TYPE : return readECMAArray(ba);
				case OBJECT_END_TYPE :
					// Unexpected object end tag in AMF stream
					trace("AMF0::readData - Warning : Unexpected object end tag in AMF stream");
					return null;
				case STRICT_ARRAY_TYPE : return readArray(ba);
				case DATE_TYPE : return readDate(ba);
				case LONG_STRING_TYPE : return readLongString(ba);
				case UNSUPPORTED_TYPE :
					// Unsupported type found in AMF stream
					trace("AMF0::readData - Warning : Unsupported type found in AMF stream");
					return "__unsupported";
				case RECORD_SET_TYPE :
					// AMF Recordsets are not supported
					trace("AMF0::readData - Warning : Unexpected recordset in AMF stream");
					return null;
				case XML_OBJECT_TYPE : return readXML(ba);
				case TYPED_OBJECT_TYPE : return readCustomClass(ba);
				case AVMPLUS_OBJECT_TYPE :
					if(amf3 == null) amf3 = new AMF3();
					return amf3.readData(ba);
				/*
				With the introduction of AMF 3 in Flash Player 9 to support ActionScript 3.0 and the 
				new AVM+, the AMF 0 format was extended to allow an AMF 0 encoding context to be 
				switched to AMF 3. To achieve this, a new type marker was added to AMF 0, the 
				avmplus-object-marker. The presence of this marker signifies that the following Object is 
				formatted in AMF 3.
				*/
				default: throw Error("AMF0::readData - Error : Undefined AMF0 type encountered '" + type + "'");
			}
		}
		
		protected function readNumber(ba:ByteArray):Number {
			return ba.readDouble();
		}
		
		protected function readBoolean(ba:ByteArray):Boolean {
			return ba.readBoolean();
		}
		
		protected function readString(ba:ByteArray):String {
			return ba.readUTF();
		}
		
		/**
		 * readObject reads the name/value properties of the amf message
		 */
		protected function readObject(ba:ByteArray):Object {
			var obj:Object = new Object();
			var varName:String = ba.readUTF();
			var type:int = ba.readByte();
			
			// 0x00 0x00 (varname) 0x09 (end object type)
			while(varName.length > 0 && type != OBJECT_END_TYPE) {
				obj[varName] = readData(ba, type);
				varName = ba.readUTF();
				type = ba.readByte();
			}
			
			readObjectCache.push(obj);
			return obj;
		}
		
		protected function readUndefined(ba:ByteArray):* {
			return undefined;
		}
		
		/**
		 * An ECMA Array or 'associative' Array is used when an ActionScript Array contains 
		 * non-ordinal indices. This type is considered a complex type and thus reoccurring 
		 * instances can be sent by reference. All indices, ordinal or otherwise, are treated 
		 * as string 'keys' instead of integers. For the purposes of serialization this type 
		 * is very similar to an anonymous Object.
		 */
		protected function readECMAArray(ba:ByteArray):Array {
			var arr:Array = new Array();
			var l:uint = ba.readUnsignedInt();
			var varName:String = ba.readUTF();
			var type:int = ba.readByte();
			
			// 0x00 0x00 (varname) 0x09 (end object type)
			while(varName.length > 0 && type != OBJECT_END_TYPE) {
				arr[varName] = readData(ba, type);
				varName = ba.readUTF();
				type = ba.readByte();
			}
			
			readObjectCache.push(arr);
			return arr;
		}
		
		/**
		 * readArray turns an all numeric keyed actionscript array
		 */
		protected function readArray(ba:ByteArray):Array {
			var l:uint = ba.readUnsignedInt();
			var arr:Array = new Array(l);
			for (var i:int = 0; i < l; ++i) {
				arr.push(readData(ba));
			}
			
			readObjectCache.push(arr);
			return arr;
		}
		
		/**
		 * readDate reads a date from the amf message
		 */
		protected function readDate(ba:ByteArray):Date {
			var ms:Number = ba.readDouble();
			
			/*
			We read in the timezone but do nothing with the value as
			we expect dates to be written in the UTC timezone. Client
			and servers are responsible for applying their own
			timezones.
			*/
			var timezone:int = ba.readShort(); // reserved, not supported. should be set to 0x0000
			//if (timezone > 720) timezone = -(65536 - timezone);
			//timezone *= -60;
			
			return new Date(ms);
		}
		
		protected function readLongString(ba:ByteArray):String {
			return ba.readUTFBytes(ba.readUnsignedInt());
		}
		
		protected function readXML(ba:ByteArray):XMLDocument {
			return new XMLDocument(readLongString(ba));
		}
		
		/**
		 * If a strongly typed object has an alias registered for its class then the type name 
		 * will also be serialized. Typed objects are considered complex types and reoccurring 
		 * instances can be sent by reference.
		 */
		protected function readCustomClass(ba:ByteArray):* {
			var className:String = ba.readUTF();
			try {
				var obj:Object = readObject(ba);
			} catch (e:Error) {
				throw new Error("AMF0::readCustomClass - Error : Cannot parse custom class");
			}
			
			obj.__traits = { type:className };
			
			// Try to type it to the class def
			/*try {
				var classDef:Class = getClassByAlias(className);
				obj = new classDef();
				obj.readExternal(ba);
			} catch (e:Error) {
				obj = readData(ba);
			}*/
			
			return obj;
		}
		
		/**
		 * writeData checks to see if the type was declared and then either
		 * auto negotiates the type or relies on the user defined type to
		 * serialize the data into amf
		 *
		 * Note that autoNegotiateType was eliminated in order to tame the 
		 * call stack which was getting huge and was causing leaks
		 *
		 * manualType allows the developer to explicitly set the type of
		 * the returned data.  The returned data is validated for most of the
		 * cases when possible.  Some datatypes like xml and date have to
		 * be returned this way in order for the Flash client to correctly serialize them
		 * 
		 * recordsets appears top on the list because that will probably be the most
		 * common hit in this method.  Followed by the
		 * datatypes that have to be manually set.  Then the auto negotiatable types last.
		 * The order may be changed for optimization.
		 */
		public function writeData(ba:ByteArray, value:*):void {
			// Number
			if (value is Number) {
				writeNumber(ba, value);
				return;
			}
			
			// Boolean
			if (value is Boolean) {
				writeBoolean(ba, value);
				return;
			}
			
			// String
			if (value is String) {
				if(value == "__unsupported") {
					writeUnsupported(ba);
				} else {
					writeString(ba, value);
				}
				return;
			}
			
			// Null
			if (value === null) {
				writeNull(ba);
				return;
			}
			
			// Undefined
			if (value === undefined) {
				writeUndefined(ba);
				return;
			}
			
			// Date
			if (value is Date) {
				writeDate(ba, value);
				return;
			}
			
			if(_avmPlus) {
				if(amf3 == null) amf3 = new AMF3();
				ba.writeByte(AVMPLUS_OBJECT_TYPE);
				amf3.writeData(ba, value);
			} else {
				// Object
				var className:String = getClassName(value);
				if (value is Object && className == "Object") {
					writeObject(ba, value);
					return;
				}
				
				// ECMA / Strict Array
				if (value is Array) {
					/*if(isStrict(value)) {
						writeArray(ba, value);
					} else {*/
						writeECMAArray(ba, value);
					//}
					return;
				}
				
				// XML Document
				if (value is XMLDocument) {
					writeXML(ba, value);
					return;
				}
				
				// Typed Object (Custom Class)
				if (value is Object && className != "Object") {
					writeTypedObject(ba, value);
					return;
				}
			}
		}
		
		/**
		 * writeNumber writes the number code (0x00) and the numeric data to the output stream
		 * All numbers passed through remoting are floats.
		 */
		protected function writeNumber(ba:ByteArray, value:Number):void {
			ba.writeByte(NUMBER_TYPE);
			ba.writeDouble(value);
		}
		
		/**
		 * writeBoolean writes the boolean code (0x01) and the data to the output stream
		 */
		protected function writeBoolean(ba:ByteArray, value:Boolean):void {
			ba.writeByte(BOOLEAN_TYPE);
			ba.writeBoolean(value);
		}
		
		/**
		 * writeString writes the string code (0x02) and the UTF8 encoded
		 * string to the output stream.
		 * Note: strings are truncated to 64k max length. Use XML as type 
		 * to send longer strings
		 */
		protected function writeString(ba:ByteArray, value:String):void {
			if (value.length < 65536) {
				ba.writeByte(STRING_TYPE);
				ba.writeUTF(value);
			} else {
				writeLongString(ba, value);
			}
		}
		
		protected function writeObject(ba:ByteArray, value:Object):void {
			if (setObjectReference(ba, value)) {
				ba.writeByte(OBJECT_TYPE);
				
				for (var key:String in value) {
					ba.writeUTF(key);
					writeData(ba, value[key]);
				}
				
				// End tag 00 00 09
				ba.writeUTF(EMPTY_STRING);
				//ba.writeByte(0x00);
				//ba.writeByte(0x00);
				ba.writeByte(OBJECT_END_TYPE);
			}
		}
		
		/**
		 * writeNull writes the null code (0x05) to the output stream
		 */
		protected function writeNull(ba:ByteArray):void {
			ba.writeByte(NULL_TYPE);
		}
		
		/**
		 * writeNull writes the undefined code (0x06) to the output stream
		 */
		protected function writeUndefined(ba:ByteArray):void {
			ba.writeByte(UNDEFINED_TYPE);
		}
		
		protected function writeECMAArray(ba:ByteArray, value:Array):void {
			if (setObjectReference(ba, value)) {
				var l:uint = value.length;
				ba.writeByte(ECMA_ARRAY_TYPE);
				ba.writeUnsignedInt(l);
				
				for (var key:String in value) {
					ba.writeUTF(key);
					writeData(ba, value[key]);
				}
				
				// End tag 00 00 09
				ba.writeByte(0x00);
				ba.writeByte(0x00);
				ba.writeByte(OBJECT_END_TYPE);
			}
		}
		
		/**
		 * Write a plain numeric array without anything fancy
		 */
		protected function writeArray(ba:ByteArray, value:Array):void {
			if (setObjectReference(ba, value)) {
				var l:uint = value.length;
				ba.writeByte(STRICT_ARRAY_TYPE);
				ba.writeInt(l);
				for (var i:int = 0; i < l; ++i) {
					writeData(ba, value[i]);
				}
			}
		}
		
		/**
		 * writeData writes the date code (0x0B) and the date value to the output stream
		 */
		protected function writeDate(ba:ByteArray, value:Date):void {
			ba.writeByte(DATE_TYPE);
			ba.writeDouble(value.time); // write date (milliseconds from 1970)
			ba.writeShort(0);// timezone reserved, not supported. should be set to 0x0000
		}
		
		protected function writeLongString(ba:ByteArray, value:String):void {
			if (value.length < 65536) {
				writeString(ba, value);
			} else {
				ba.writeByte(LONG_STRING_TYPE);
				ba.writeUTFBytes(value);
			}
		}
		
		/**
		 * writeUnsupported writes the unsupported code (13) to the output stream
		 */
		protected function writeUnsupported(ba:ByteArray):void {
			ba.writeByte(UNSUPPORTED_TYPE);
		}
		
		/**
		 * writeXML writes the xml code (0x0F) and the XML string to the output stream
		 * Note: strips whitespace
		 * @param string $d The XML string
		 */
		protected function writeXML(ba:ByteArray, value:XMLDocument):void {
			if (setObjectReference(ba, value)) {
				ba.writeByte(XML_OBJECT_TYPE);
				var strXML:String = value.toString();
				strXML = strXML.replace(/^\s+|\s+$/g, ''); // Trim
				//strXML = strXML.replace(/\>(\n|\r|\r\n| |\t)*\</g, "><"); // Strip whitespaces, not done by native encoder
				ba.writeUnsignedInt(strXML.length);
				ba.writeUTFBytes(strXML);
			}
		}
		
		/**
		 * writePHPObject takes an instance of a class and writes the variables defined
		 * in it to the output stream.
		 * To accomplish this we just blanket grab all of the object vars with get_object_vars
		 */
		protected function writeTypedObject(ba:ByteArray, value:Object):void {
			if (setObjectReference(ba, value)) {
				ba.writeByte(TYPED_OBJECT_TYPE);
				ba.writeUTF(getClassName(value));
				writeObject(ba, value);
			}
		}
		
		protected function getObjectReference(ba:ByteArray):Object {
			var ref:int = ba.readUnsignedShort();
			if (ref >= readObjectCache.length) {
				throw Error("AMF0::getObjectReference - Error : Undefined object reference '" + ref + "' :: " + ba.position);
				return null;
			}
			
			return readObjectCache[ref];
		}
		
		protected function setObjectReference(ba:ByteArray, o:*):Boolean {
			var refNum:int;
			if (writeObjectCache != null && (refNum = hasItem(writeObjectCache, o)) != -1) {
                ba.writeByte(REFERENCE_TYPE);
				writeUnsignedShort(ba, refNum);
                return false;
	        } else {
				if (writeObjectCache == null) writeObjectCache = new Array();
				if (writeObjectCache.length < MAX_STORED_OBJECTS) {
					var bytes:ByteArray = new ByteArray();
					bytes.writeObject(o);
					writeObjectCache.push(bytes.toString());
				}
				return true;
			}
		}
		
		/**
		 * Grab class name [class ClassName]
		 * 
		 * @param	obj
		 * @return
		 */
		protected function getClassName(obj:Object):String {
			var desc:XML = describeType(obj);
			return desc.@name.toString();
		}
		
		protected function writeUnsignedShort(ba:ByteArray, value:int):void {
			var b1:int = (value / 256);
			var b0:int = (value % 256);
			ba.writeByte(b0);
			ba.writeByte(b1);
		}
		
		protected function hasItem(array:Array, item:*):int {
			var i:uint = array.length;
			while (i--) {
				if(isSame(array[i], item)) return i;
			}
			return -1;
		}
		
		protected function isSame(item1:*, item2:*):Boolean {
			// If it's an object
			if(typeof item1 == "object" && typeof item2 == "object") {
				var bytes1:ByteArray = new ByteArray();
				bytes1.writeObject(item1);
				
				var bytes2:ByteArray = new ByteArray();
				bytes2.writeObject(item2);
				
				return (bytes1.toString() === bytes2.toString());
				
				// If it's the same type of object
				/*if(Object(item1).constructor == Object(item2).constructor) {
					for (var i:String in item1) {
						if (typeof item1[i] == "object") {
							// Only return if they don't match
							if(!isSame(item1[i], item2[i])) return false;
						} else if (item1[i] != item2[i]) {
							return false;
						}
					}
					
					return true;
				} else {
					return false;
				}*/
			}
			
			// If it's a simple type
			return (item1 === item2);
		}
		
		/*protected function search(array:Array, item:*):int {
			var i:uint = array.length;
			while (i--) {
				if(array[i] === item) return i;
			}
			return -1;
		}*/
		
		/*protected function isStrict(array:Array):Boolean {
			var l:int = array.length;
			var count:int = 0;
			var key:String;
			for(key in array) {
				count++;
			}
			
			return (count == l);
		}*/
	}
}