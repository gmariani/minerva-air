package com.coursevector.minerva {

	/*
	 * The Alphanum Algorithm is an improved sorting algorithm for strings
	 * containing numbers.  Instead of sorting numbers in ASCII order like
	 * a standard sort, this algorithm sorts numbers in numeric order.
	 *
	 * The Alphanum Algorithm is discussed at http://www.DaveKoelle.com
	 *
	 *
	 * This library is free software; you can redistribute it and/or
	 * modify it under the terms of the GNU Lesser General Public
	 * License as published by the Free Software Foundation; either
	 * version 2.1 of the License, or any later version.
	 *
	 * This library is distributed in the hope that it will be useful,
	 * but WITHOUT ANY WARRANTY; without even the implied warranty of
	 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
	 * Lesser General Public License for more details.
	 *
	 * You should have received a copy of the GNU Lesser General Public
	 * License along with this library; if not, write to the Free Software
	 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
	 *
	 */
	public class AlphaNumericSort {
		public static var field:String = '';
		
		private static function isDigit(ch:String):Boolean {
			var code:int = ch.charCodeAt(0);
			return code >= 48 && code <= 57;
		}

		/** Length of string is passed in for improved efficiency (only need to calculate it once) **/
		private static function getChunk(s:String, slength:int, marker:int):String {
			var result:String = "";
			var c:String = s.charAt(marker);
			result += c;
			marker++;
			if (isDigit(c)) {
				while (marker < slength) {
					c = s.charAt(marker);
					if (!isDigit(c)) break;
					result += c;
					marker++;
				}
			} else {
				while (marker < slength) {
					c = s.charAt(marker);
					if (isDigit(c)) break;
					result += c;
					marker++;
				}
			}
			return result;
		}
		
		/**
		 * Comparison function to sort a list of Strings alphanumerically.
		 */
		public static function compare(o1:Object, o2:Object):int {
			var s1:String = o1[AlphaNumericSort.field];
			var s2:String = o2[AlphaNumericSort.field];
			var thisMarker:int = 0;
			var thatMarker:int = 0;
			var s1Length:int = s1.length;
			var s2Length:int = s2.length;

			while (thisMarker < s1Length && thatMarker < s2Length) {
				var thisChunk:String = getChunk(s1, s1Length, thisMarker);
				thisMarker += thisChunk.length;

				var thatChunk:String = getChunk(s2, s2Length, thatMarker);
				thatMarker += thatChunk.length;

				// If both chunks contain numeric characters, sort them numerically
				var result:int = 0;
				if (isDigit(thisChunk.charAt(0)) && isDigit(thatChunk.charAt(0))) {
					// Simple chunk comparison by length.
					var thisChunkLength:int = thisChunk.length;
					result = thisChunkLength - thatChunk.length;
					// If equal, the first different number counts
					if (result == 0) {
						for (var i:int = 0; i < thisChunkLength; i++)	{
							result = thisChunk.charCodeAt(i) - thatChunk.charCodeAt(i);
							if (result != 0) return result;
						}
					}
				} else {
					if (thisChunk < thatChunk) { 
						result = -1; 
					} else if (thisChunk > thatChunk) { 
						result = 1; 
					} else { 
						result = 0; 
					}
				}

				if (result != 0) return result;
			}

			return s1Length - s2Length;
		}
	}
}