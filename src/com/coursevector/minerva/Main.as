import air.update.ApplicationUpdaterUI;
import air.update.events.UpdateEvent;

import com.coursevector.data.JSFormatter;
import com.coursevector.formats.AMF;
import com.coursevector.formats.SOL;
import com.coursevector.minerva.AboutWindow;
import com.coursevector.minerva.AlphaNumericSort;
import com.google.analytics.AnalyticsTracker;
import com.google.analytics.GATracker;

import flash.desktop.Clipboard;
import flash.desktop.ClipboardFormats;
import flash.desktop.ClipboardTransferMode;
import flash.desktop.NativeApplication;
import flash.desktop.NativeDragActions;
import flash.desktop.NativeDragManager;
import flash.events.ErrorEvent;
import flash.events.Event;
import flash.events.InvokeEvent;
import flash.events.KeyboardEvent;
import flash.events.MouseEvent;
import flash.events.NativeDragEvent;
import flash.filesystem.File;
import flash.filesystem.FileMode;
import flash.filesystem.FileStream;
import flash.net.FileFilter;
import flash.net.SharedObject;
import flash.utils.ByteArray;
import flash.utils.Endian;
import flash.utils.describeType;
import flash.utils.getDefinitionByName;
import flash.utils.setTimeout;
import flash.xml.XMLDocument;

import mx.collections.*;
import mx.controls.Alert;
import mx.controls.TextInput;
import mx.controls.Tree;
import mx.controls.listClasses.*;
import mx.controls.treeClasses.TreeItemRenderer;
import mx.controls.treeClasses.TreeListData;
import mx.core.IUITextField;
import mx.core.mx_internal;
import mx.events.CloseEvent;
import mx.events.CollectionEvent;
import mx.events.CollectionEventKind;
import mx.events.ItemClickEvent;
import mx.events.ListEvent;
import mx.events.ToolTipEvent;
import mx.managers.SystemManager;
import mx.utils.ArrayUtil;

[Embed("assets/icons/array.png")]
private var arrayIcon:Class;

[Embed("assets/icons/boolean.png")]
private var booleanIcon:Class;

[Embed("assets/icons/bytearray.png")]
private var bytearrayIcon:Class;

[Embed("assets/icons/date.png")]
private var dateIcon:Class;

[Embed("assets/icons/int.png")]
private var intIcon:Class;

[Embed("assets/icons/lostreference.png")]
private var lostreferenceIcon:Class;

[Embed("assets/icons/mixed.png")]
private var mixedIcon:Class;

[Embed("assets/icons/none.png")]
private var noneIcon:Class;

[Bindable]
[Embed("assets/icons/null.png")]
private var nullIcon:Class;

[Embed("assets/icons/number.png")]
private var numberIcon:Class;

[Embed("assets/icons/object.png")]
private var objectIcon:Class;

[Embed("assets/icons/ref.png")]
private var refIcon:Class;

[Embed("assets/icons/string.png")]
private var stringIcon:Class;

[Embed("assets/icons/undefined.png")]
private var undefinedIcon:Class;

[Embed("assets/icons/xml.png")]
private var xmlIcon:Class;

[Embed("assets/icons/vector.png")]
private var vectorIcon:Class;

[Bindable]
private var showInspector:Boolean = false;

[Bindable]
private var hasFile:Boolean = false;

[Bindable]
private var showOpen:Boolean = true;

[Bindable]
private var showSave:Boolean = false;

[Bindable]
private var arrDataTypes:Array = [
	'Array', 'Boolean', 'ByteArray', 'Date', 
	'Integer', 'Null', 'Number', 'Object', 
	'String', 'Undefined', 'XML', 'XMLDocument'
];
// Minerva
private var appUpdater:ApplicationUpdaterUI = new ApplicationUpdaterUI();
private var aboutWin:AboutWindow;

[Bindable]
private var isEditor:Boolean = true;

private var isStartEdit:Boolean = false;
private var lastSelected:Object;

// JS Formatter
private var objJSConfig:Object = new Object();
private var fmtrJS:JSFormatter = new JSFormatter();

// AMF Editor
private var isJSON:Boolean = false;
private var isSOL:Boolean = false;
private var fileRead:File = File.userDirectory;
private var fileWrite:File = File.desktopDirectory;
private var fileExport:File = File.desktopDirectory;
[Bindable]
private var objData:Object = new Object();
private var nVersion:int = -1;
private var solReader:SOL = new SOL();
private var amfReader:AMF = new AMF();
private var fileFilters:Array = [
								new FileFilter("SOL Files", "*.sol", "SOL"), 
								new FileFilter("Remoting AMF Files", "*.amf", "AMF")
								];								
// For Sorting the Tree
private var _uid:int = 0;
[Bindable]
private var _dataProvider:ArrayCollection = new ArrayCollection([objData]);
private var _openItems:Array;
private var _verticalScrollPosition:Number;
private var siteMapIDField:String = "id";
private var sortLabelField:String = "name-asc";
private var sortItems:Boolean = true;
private var rememberOpenState:Boolean = false;

use namespace mx_internal;

/////////////////
// Application //
/////////////////

// Event handler to initialize the MenuBar control.
private function init():void {
	// Init Updater			
	appUpdater.updateURL = "http://www.coursevector.com/projects/minerva/update.xml"; // Server-side XML file describing update
	appUpdater.isCheckForUpdateVisible = false; // We won't ask permission to check for an update
	appUpdater.addEventListener(UpdateEvent.INITIALIZED, onUpdate); // Once initialized, run onUpdate
	appUpdater.addEventListener(ErrorEvent.ERROR, errorHandler); // If something goes wrong, run onError
	appUpdater.initialize(); // Initialize the update framework
	
	// Load prefs
	var so:SharedObject = SharedObject.getLocal("settings");
	objJSConfig.space_after_anon_function = true;
	if(so.data.hasOwnProperty("indent_index")) {
		ddSize.selectedIndex = so.data.indent_index;
		
		objJSConfig.indent_size = ddSize.selectedItem.data;
		objJSConfig.indent_char = objJSConfig.indent_size == 1 ? '\t' : ' ';
		objJSConfig.braces_on_own_line = so.data.braces_on_own_line;
		objJSConfig.preserve_newlines = so.data.preserve_newlines;
		objJSConfig.detect_packers = so.data.detect_packers;
		objJSConfig.keep_array_indentation = so.data.keep_array_indentation;
		
		cbBraces.selected = objJSConfig.braces_on_own_line;
		cbPreserve.selected = objJSConfig.preserve_newlines;
		cbPackers.selected = objJSConfig.detect_packers;
		cbKeepIndentation.selected = objJSConfig.keep_array_indentation;
	}
	
	// Init Listeners
	this.addEventListener(NativeDragEvent.NATIVE_DRAG_ENTER, dragHandler);
	this.addEventListener(NativeDragEvent.NATIVE_DRAG_DROP, dragHandler);
	NativeApplication.nativeApplication.addEventListener(InvokeEvent.INVOKE, invokeHandler, false, 0, true);
	solReader.addEventListener(ErrorEvent.ERROR, errorHandler, false, 0, true);
	solReader.addEventListener(Event.COMPLETE, openCompleteHandler, false, 0, true);
	amfReader.addEventListener(ErrorEvent.ERROR, errorHandler, false, 0, true);
	amfReader.addEventListener(Event.COMPLETE, openCompleteHandler, false, 0, true);
}

private function initTracker():void {
	// Analytics
	var tracker:AnalyticsTracker = new GATracker(this.stage, "UA-349755-1", "AS3", false);
	tracker.trackPageview("/tracking/projects/minerva");
}

private function invokeHandler(e:InvokeEvent):void {
	if(e.arguments.length > 0) {
		var l:int = e.arguments.length;
		var invCommands:Object = { };
		while (l--) {
			invCommands[e.arguments[l].toLowerCase()] = e.arguments[l];
		}
		
		if(fileRead.hasEventListener(Event.SELECT)) fileRead.removeEventListener(Event.SELECT, openHandler);
		fileRead = new File(e.arguments[0]);
		openHandler();
		if (invCommands['json-export'])	{
			fileExport = new File(fileWrite.url);
			saveJSONHandler();
		}
		if (invCommands['exit']) this.close();
	}
}

private function onClickTab(e:ItemClickEvent):void {
	if(e.label == "AMF Inspector") {
		vsNav.selectedIndex = 0;
		isEditor = true;
		showOpen = isEditor && !hasFile;
		showSave = isEditor && hasFile;
	} else {
		vsNav.selectedIndex = 1;
		isEditor = false;
		showOpen = false;
		showSave = false;
	}
}

private function onClickAbout():void {
	aboutWin = new AboutWindow();
	aboutWin.open();
}

private function fileClose():void {
	objData = {};
	nVersion = -1;
	updateTreedataProvider(new ArrayCollection([objData]));
	showInspector = false;
	hasFile = false;
	showOpen = isEditor && !hasFile;
	showSave = isEditor && hasFile;
	isSOL = false;
	this.title = ".minerva";
}

private function dragHandler(e:NativeDragEvent):void {
	switch(e.type) {
		case NativeDragEvent.NATIVE_DRAG_ENTER :
			var cb:Clipboard = e.clipboard;
			if(cb.hasFormat(ClipboardFormats.FILE_LIST_FORMAT)){
				NativeDragManager.dropAction = NativeDragActions.LINK;
				NativeDragManager.acceptDragDrop(this);
			} else {
				 Alert.show('Unrecognized file format', 'Alert', Alert.OK);
			}
			break;
		case NativeDragEvent.NATIVE_DRAG_DROP :
			var arrFiles:Array = e.clipboard.getData(ClipboardFormats.FILE_LIST_FORMAT, ClipboardTransferMode.ORIGINAL_ONLY) as Array;
			if(fileRead.hasEventListener(Event.SELECT)) fileRead.removeEventListener(Event.SELECT, openHandler);
			fileRead = arrFiles[0];
			openHandler();
			break;
	}
}

private function onUpdate(event:UpdateEvent):void {
	appUpdater.checkNow(); // Go check for an update now
}

//////////////////////////
// JavaScript Formatter //
//////////////////////////

private function formatHandler(event:MouseEvent):void {
	txtCode.text = fmtrJS.format(txtCode.text.replace(/^\s+/, ''), objJSConfig);
}

private function updateConfig():void {
	objJSConfig.indent_size = ddSize.selectedItem.data;
	objJSConfig.indent_char = objJSConfig.indent_size == 1 ? '\t' : ' ';
	objJSConfig.braces_on_own_line = cbBraces.selected;
	objJSConfig.preserve_newlines = cbPreserve.selected;
	objJSConfig.detect_packers = cbPackers.selected;
	objJSConfig.space_after_anon_function = true;
	objJSConfig.keep_array_indentation = cbKeepIndentation.selected;
	
	// Save Pref via Shared Object
	var so:SharedObject = SharedObject.getLocal("settings");
	so.data.braces_on_own_line = cbBraces.selected;
	so.data.preserve_newlines = cbPreserve.selected;
	so.data.detect_packers = cbPackers.selected;
	so.data.indent_index = ddSize.selectedIndex;
	so.data.keep_array_indentation = cbKeepIndentation.selected;
	
    try {
		so.flush(10000);
    } catch (e:Error) {
		Alert.show("Error...Could not write SharedObject to disk\n");
    }
}

////////////////
// SOL Editor //
////////////////

private function treeOverHandler(e:ListEvent):void {
	e.itemRenderer.addEventListener(ToolTipEvent.TOOL_TIP_SHOW, treeTipHandler, false, 0, true);
}

private function treeTipHandler(e:ToolTipEvent):void {
	e.currentTarget.removeEventListener(ToolTipEvent.TOOL_TIP_SHOW, treeTipHandler);
	
	var label:IUITextField = TreeItemRenderer(e.currentTarget).mx_internal::getLabel();
	e.toolTip.move(e.toolTip.x + label.measuredWidth, e.toolTip.y);
}

private function onChangeSort(e:Event):void {
	sortLabelField = cbSort.selectedItem.data;
	onClickRefresh();
}

private function onClickRefresh():void {
	if(hasFile) {
		rememberOpenState = true;
		if(fileRead) openHandler();
		rememberOpenState = false;
	}
}

private function onClickInsert():void {
	_uid++;
	var o:Object = {name:'New Item ' + _uid, value:'', type:'String', id:_uid};
	
	var parent:Object = dataTree.selectedItem;
	if (parent == null) return;
	if (!dataTree.dataDescriptor.isBranch(parent)) parent = dataTree.getParentItem(parent);
	//if (!parent.children) parent = dataTree.getParentItem(parent);
	
	var parentRenderer:IListItemRenderer = dataTree.itemToItemRenderer(parent);
	var parentIndex:int = dataTree.itemRendererToIndex(parentRenderer);
	
	parent.children.push(o);
	if (parent.traits && parent.traits.count) {
		// Add member to members array
		parent.traits.members.push(o);
		
		// Increase member count
		parent.traits.count++;
	}
	//dataTree.selectedItem = parent;
	
	/*dataTree.invalidateDisplayList();
	dataTree.invalidateProperties();
	dataTree.invalidateLayering();
	dataTree.invalidateLayoutDirection();
	dataTree.invalidateList();
	dataTree.invalidateSize();
	
	dataTree.validateDisplayList();
	dataTree.validateNow();
	dataTree.validateProperties();
	dataTree.validateSize(true);*/
	
	_dataProvider.refresh();
	dataTree.invalidateList();
	//_dataProvider.dispatchEvent(new CollectionEvent(CollectionEvent.COLLECTION_CHANGE, false, false, CollectionEventKind.ADD, -1, -1, [o]));
	
	dataTree.selectedItem = o;
	//vsType.selectedChild = StringType;
	
	/*
	//var parent:Object = dataTree.getParentItem(node);
	//var parentRenderer:IListItemRenderer = dataTree.itemToItemRenderer(parent);
	// If parent node is not in view, it can't be found
	//if (parentRenderer == null) return;
	
	var p:int = 0;//dataTree.itemRendererToIndex(parentRenderer);
	var i:int = dataTree.itemRendererToIndex(dataTree.itemToItemRenderer(parent));
	dataTree.dataDescriptor.addChildAt(parent, o, i - p - 1);
	vsType.selectedChild = StringType;
	
	if (parent.traits && parent.traits.count) {
		// Add member to members array
		parent.traits.members.push(o);
		
		// Increase member count
		parent.traits.count++;
	}
	
	if (parent.type == "Array") {
		parent.children.push(o);
	}*/
}

private function onClickRemove():void {
	var node:Object = dataTree.selectedItem;
	if (node == null) return;
	
	var parent:Object = dataTree.getParentItem(node);
	var parentRenderer:IListItemRenderer = dataTree.itemToItemRenderer(parent);
	// If parent node is not in view, it can't be found
	if (parentRenderer == null) return;
	
	var p:int = dataTree.itemRendererToIndex(parentRenderer);
	var i:int = dataTree.itemRendererToIndex(dataTree.itemToItemRenderer(node));
	dataTree.dataDescriptor.removeChildAt(parent, dataTree.selectedItem, i - p - 1);
	vsType.selectedChild = ObjectType;
	
	if (parent.traits && parent.traits.count) {
		// Remove member from members array
		for (i = 0; i < parent.traits.count; i++) {
			if (parent.traits.members[i] == node.name) {
				parent.traits.members.splice(i,1);
				break;
			}
		}
		
		// Reduce member count
		parent.traits.count--;
	}
	
	if (parent.type == "Array") {
		for (i = 0; i < parent.children; i++) {
			if (parent.children[i].id == node.id) {
				parent.children.splice(i,1);
				break;
			}
		}
	}
}

private function fileOpen():void {
	// Find location of flashlog.txt
	var strUserDir:String = fileRead.url;
	if(fileRead.hasEventListener(Event.SELECT)) fileRead.removeEventListener(Event.SELECT, openHandler);
	fileRead = fileRead.resolvePath(strUserDir + "/Application Data/Macromedia/Flash Player/"); // Win
	if(fileRead.exists) {
		// Windows
	} else {
		fileRead = fileRead.resolvePath(strUserDir + "/Library/Preferences/Macromedia/Flash Player/"); // Mac
		if(fileRead.exists) {
			// Mac
		} else {
			fileRead = fileRead.resolvePath(strUserDir + "/.macromedia/Flash_Player/"); // Linux
			// Linux
		}
	}
	
	fileRead.addEventListener(Event.SELECT, openHandler, false, 0, true);
	fileRead.browse(fileFilters);
}

private function errorHandler(e:ErrorEvent):void {
	Alert.show(e.text, 'Error', Alert.OK);
}

private function openHandler(e:Event = null):void {
	// Update fileWrite
	if(fileExport.hasEventListener(Event.SELECT)) fileExport.removeEventListener(Event.SELECT, saveJSONHandler);
	if(fileWrite.hasEventListener(Event.SELECT)) fileWrite.removeEventListener(Event.SELECT, saveHandler);
	fileWrite = new File(fileRead.url);
	fileWrite.addEventListener(Event.SELECT, saveHandler, false, 0, true);
	fileExport.addEventListener(Event.SELECT, saveJSONHandler, false, 0, true);
	
	var ba:ByteArray = new ByteArray();
	
	// Read file into ByteArray
	var bytes:FileStream = new FileStream();
	bytes.open(fileRead, FileMode.READ);
	bytes.readBytes(ba);
	bytes.close();
	
	if(fileRead.extension.toLowerCase() == "amf") {
		isSOL = false;
		
		// Read AMF File
		if (CONFIG::debugging == true) {
			amfReader.deserialize(ba, systemManager);
		} else {
			try {
				amfReader.deserialize(ba, systemManager);
			} catch (err:Error) {
				Alert.show(err.message, 'Error Opening', Alert.OK);
			}
		}
	} else {
		isSOL = true;
		
		// Read SOL File
		if (CONFIG::debugging == true) {
			solReader.deserialize(ba, systemManager);
		} else {
			try {
				solReader.deserialize(ba, systemManager);
			} catch (err:Error) {
				Alert.show(err.message, 'Error Opening', Alert.OK);
			}
		}
	}
	
	// Display opening message
	updateTreedataProvider(new ArrayCollection([{name:'Opening...'}]));
	
	showInspector = false;
	hasFile = true;
	showOpen = isEditor && !hasFile;
	showSave = isEditor && hasFile;
	vsType.selectedChild = EmptyType;
	
	this.title = ".minerva - " + fileRead.name;
}

private function openCompleteHandler(e:Event):void {
	var reader:Object = isSOL ? solReader : amfReader;
	// Grab AMF version
	nVersion = reader.amfVersion;
	
	// Convert Data to dataprovider object
	_uid = 0;
	objData = toDPObject(isSOL ? solReader.fileName : fileRead.name, reader.data);
	
	var fileSize:String = fileRead.size > 1024 ? Number(fileRead.size / 1024).toFixed(2) + "kb" : fileRead.size + "b"; 
	objData.type = "AMF" + nVersion + " (" + fileSize + ")";
	
	// Convert Object to an ArrayCollection
	updateTreedataProvider(new ArrayCollection(ArrayUtil.toArray(objData)));
}

// Not sure about using this, lose native data typing
private function toXML(name:String, value:*):XML {
	var type:String = determineType(value);
	var xml:XML;
	
	if(type == "Array" || type == "Object" || type.indexOf('Vector') > -1) {
		// For custom classes, pass the class name and traits
		var traits:Object;
		if(type == "Object" && value.hasOwnProperty("__traits")) {
			type = value.__traits.type;
			traits = value.__traits;
			delete value.__traits;
		} else if (type.indexOf('Vector.<int>') == -1 &&
			type.indexOf('Vector.<uint>') == -1 &&
			type.indexOf('Vector.<Number>') == -1 &&
			type.indexOf('Vector') > -1) {
			type = value[0].type;
			traits = value[0];
			delete value.shift();
		}
		
		// Parent node XML
		xml = <node name={name} type={type} id={_uid} traits={JSON.stringify(traits)} />;
		
		// Child node XML
		// If data is a typed (class) object, for...in won't read it
		var desc:XML = describeType(value);
		type = desc.@name.toString();
		if (type.indexOf('::') != -1) type = type.split('::').pop();
		
		if (type.indexOf('Vector') > -1) {
			for (var i:int = 0, l:int = value.length; i < l; i++) {
				xml.appendChild(toXML(String(i), value[i]));
			}
		} else if(type != "Object" && 
			type != 'ObjectProxy' && 
			type != 'ManagedObjectProxy' && 
			type != "Array") {
			for each (var v:XML in desc.variable) {
				name = v.@name.toString();
				xml.appendChild(toXML(name, value[name]));
			}
		} else {
			for (name in value) {
				xml.appendChild(toXML(name, value[name]));
			}
		}
	} else if (type == "ByteArray") {
		var str:String = byteArray2String(value as ByteArray);
		xml = <node name={name} value={str} type={type} id={_uid} />;
	} else if (type == "XMLDocument" || type == "XML") {
		xml = <node name={name} value={value.toString()} type={type} id={_uid} />;
	} else {
		xml = <node name={name} value={value} type={type} id={_uid} />;
	}
	_uid++;
	
	return xml;
}

//////////////////
// Sort Tree Functions

private function updateTreedataProvider(value:ArrayCollection):void {
    if (_dataProvider != null) saveTreeOpenState();
    
    _dataProvider = value;
    if (sortItems == true) {
        // Sort the Array Collection                
        //_dataProvider.sort = getSort();
        
        // Sort the nested arrays of the ArrayCollection using recursion
        for (var i:int = 0; i < _dataProvider.length; i++) {
            sortTree(_dataProvider.getItemAt(i));
        }
        _dataProvider.refresh();
    }
    dataTree.dataProvider = _dataProvider;
    dataTree.validateNow();
    
    if (rememberOpenState == true) {
        for (var t:int = 0; t < _dataProvider.length; t++) {
            if (_dataProvider.getItemAt(t).hasOwnProperty("children")) {
                openTreeItems(_dataProvider.getItemAt(t));
            }
        }
        
        dataTree.verticalScrollPosition = _verticalScrollPosition;
    }
}

/*private function getSort():Sort {
	var treeSort:Sort = new Sort();
	if (sortLabelField.indexOf('type') > -1) {
		if (sortLabelField.indexOf('desc') > -1) {
			treeSort.fields = [new SortField('type'), new SortField('name')];
		} else {
			treeSort.fields = [new SortField('type', false, true), new SortField('name', false, true)];
		}
		treeSort.compareFunction = AlphaNumericSort.compare;
	} else {
		if (sortLabelField.indexOf('desc') > -1) {
			treeSort.fields = [new SortField('name')];
		} else {
			treeSort.fields = [new SortField('name', false, true)];
		}
		treeSort.compareFunction = sortOnName;
	}
	return treeSort;
}*/

private function sortOnName(a:Object, b:Object):Number {
	if (!isNaN(Number(a.name))) {
		var aIndex:int =  Number(a.name);
		var bIndex:int =  Number(b.name);
			
		if(aIndex > bIndex) {
			return 1;
		} else if(aIndex < bIndex) {
			return -1;
		} else  {
			//aIndex == bIndex
			return 0;
		}
	} else {
		var aName:String = a.name;
		var bName:String = b.name;
		
		if(aName > bName) {
			return 1;
		} else if(aName < bName) {
			return -1;
		} else  {
			//aName == bName
			return 0;
		}
	}
}

private function sortOnType(a:Object, b:Object):Object {
	var aType:String = a.type;
	var bType:String = b.type;
	
	//sort first field
	if(aType < bType) {
		return -1;
	} else if(aType > bType) {
		return 1;
	}
	
	//if first field is the same, then sort on second field
	if(aType == bType) {
		if (!isNaN(Number(a.name))) {
			var aIndex:int =  Number(a.name);
			var bIndex:int =  Number(b.name);
			
			if(aIndex > bIndex) {
				return 1;
			} else if(aIndex < bIndex) {
				return -1;
			}
		} else {
			var aName:String = a.name;
			var bName:String = b.name;
			
			if(aName > bName) {
				return 1;
			} else if(aName < bName) {
				return -1;
			}
		}
	}
	
	return 0;
}

private function sortTree(object:Object):void {
    if (object.hasOwnProperty("children")) {
		if (sortLabelField.indexOf('type') > -1) {
			if (sortLabelField.indexOf('asc') > -1) {
				object.children.sort(sortOnType);
			} else {
				object.children.sort(sortOnType, Array.DESCENDING);
			}
		} else {
			if (sortLabelField.indexOf('asc') > -1) {
				object.children.sort(sortOnName);
			} else {
				object.children.sort(sortOnName, Array.DESCENDING);
			}
		}
		
        for (var t:int = 0; t < object.children.length; t++) {
            sortTree(object.children[t]);
        }    
    }
}
            
private function openTreeItems(object:Object):void {
    for (var i:int = 0; i < _openItems.length; i++) {
        if (object[siteMapIDField] == _openItems[i]) {
            dataTree.expandItem(object, true);
            break;
        }
    }
    
    if (object.hasOwnProperty("children")) {
        for (var t:int = 0; t < object.children.length; t++) {
            openTreeItems(object.children[t]);
        }    
    }
}
                        
private function saveTreeOpenState():void {
    _verticalScrollPosition = dataTree.verticalScrollPosition;
    _openItems = [];
    for (var i:int = 0; i < dataTree.openItems.length; i++) {
        if (dataTree.openItems[i].hasOwnProperty(siteMapIDField)) {
            _openItems[i] = dataTree.openItems[i][siteMapIDField];
        }
    }                
}

///////////////////

// Converts simple object to dataprovider object
private function toDPObject(name:String, value:*):Object {
	var o:Object = {};
	var type:String = determineType(value);
	
	if (type == "Array" || type == "Object" || type.indexOf('Vector') > -1) {
		// For custom classes, pass the class name and traits
		var traits:Object;
		if(type == "Object" && value.hasOwnProperty("__traits")) {
			type = value.__traits.type;
			traits = value.__traits;
			delete value.__traits;
		} else if(type.indexOf('Vector.<int>') == -1 &&
			type.indexOf('Vector.<uint>') == -1 &&
			type.indexOf('Vector.<Number>') == -1 &&
			type.indexOf('Vector') > -1) {
			type = value[0].type;
			traits = value[0];
			delete value.shift();
		}
		
		// Parent Object
		o = {name:name, type:type, id:_uid, traits:traits};
		o.children = new Array();
		
		// Child Objects
		// If data is a typed (class) object, for...in won't read it
		var desc:XML = describeType(value);
		name = desc.@name.toString();
		if (name.indexOf('::') != -1) name = name.split('::').pop();
		if (name.indexOf('Vector') > -1) {
			for (var i:int = 0, l:int = value.length; i < l; i++) {
				o.children.push(toDPObject(String(i), value[i]));
			}
		} else if(name != "Object" && 
				name != 'ObjectProxy' && 
				name != 'ManagedObjectProxy' && 
				name != "Array") {
			for each (var v:XML in desc.variable) {
				name = v.@name.toString();
				o.children.push(toDPObject(name, value[name]));
			}
		} else {
			for (name in value) {
				o.children.push(toDPObject(name, value[name]));
			}
		}
	} else if (type == "ByteArray") {
		var str:String = byteArray2String(value as ByteArray);
		o = {name:name, value:str, type:type, id:_uid};
	} else if(type == "XMLDocument" || type == "XML") {
		o = {name:name, value:value.toString(), type:type, id:_uid};
	} else {
		o = {name:name, value:value, type:type, id:_uid};
	}
	_uid++;
	
	return o;
}

// Converts dataprovider object to simple object
private function toObject(arr:Array, o:*):* {
	if(!arr) arr = [];
	if(!o) o = {};
	var l:uint = arr.length;
	for(var i:int = 0; i < l; ++i) {
		var data:Object = arr[i];
		var value:*;
		if(data.type == "ByteArray") {
			value = string2ByteArray(data.value);
		} else if(data.type == "Array") {
			value = toObject(data.children, []) as Array;
		} else if(data.type == "Object") {
			value = toObject(data.children, {});
		} else if(data.type == "Vector.<int>") {
			value = toObject(data.children, new Vector.<int>());
		} else if(data.type == "Vector.<uint>") {
			value = toObject(data.children, new Vector.<uint>());
		} else if(data.type == "Vector.<Number>") {
			value = toObject(data.children, new Vector.<Number>());
		} else if(data.type == "Vector.<Object>" || data.type.indexOf('Vector') > -1) {
			value = toObject(data.children, new Vector.<Object>());
		} else {
			var type:String = data.type;
			if(type == "Undefined") {
				value = undefined;
			} else if(type == "Null") {
				value = null;
			} else if(type == "Unsupported") {
				value = "__unsupported";
			} else {
				if(type == "Integer") type = "int";
				if(type == "int" && (data.value %1 != 0)) type = "Number";
				if(type == "int" && (data.value >= int.MAX_VALUE || data.value <= int.MIN_VALUE)) {
					type = "Number";
					data.type = "Number";
				}
				if(type == "XMLDocument") type = "flash.xml.XMLDocument";
				
				try {
					var c:Class = getDefinitionByName(type) as Class;
					// Handle these differently, use the 'new' keyword
					if(type == "flash.xml.XMLDocument" || type == "Date") {
						value = new c(data.value);
					} else {
						value = c(data.value);
					}
				} catch (e:Error) {
					//type.indexOf('flex') >= -1
					value = toObject(data.children, {});
				}
			}
		}
		
		// Handle Vectors special
		if (data.type.indexOf('Vector') > -1 && data.traits) {
			value.unshift(data.traits);
		} else if (data.traits) {
			value.__traits = data.traits;
		}
		
		o[data.name] = value;
	}
	
	return o;
}

private function fileSaveAs():void {
	fileWrite.browseForSave("Save As");
}

private function fileSaveAsJSON():void {
	fileExport.url = fileWrite.url;
	if(fileExport.extension == null || fileExport.extension.toLowerCase() != "json") {
		fileExport.url += ".json";
	}
	fileExport.browseForSave('Save As');
}
private var solWriter:SOL;
private var amfWriter:AMF;

private function fileSave():void {
	var o:Object = {};
	var a:Array = _dataProvider.source;
	var fileName:String = a[0].name;
	
	if (CONFIG::debugging == true) {
		if(a[0].hasOwnProperty("children")) o = toObject(a[0].children, o);
	} else {
		try {
			if(a[0].hasOwnProperty("children")) o = toObject(a[0].children, o);
		} catch (e:Error) {
			Alert.show(e.message, 'Error Saving', Alert.OK);
			return;
		}
	}
	
	// Display opening message
	updateTreedataProvider(new ArrayCollection([{name:'Saving...'}]));
	
	if(isSOL) {
		solWriter = new SOL();
		solWriter.addEventListener(Event.COMPLETE, saveCompleteHandler, false, 0, true);
		if (CONFIG::debugging == true) {
			solWriter.serialize(systemManager, fileName, o, nVersion);
		} else {
			try {
				solWriter.serialize(systemManager, fileName, o, nVersion);
			} catch (e:Error) {
				Alert.show(e.message, 'Error Saving', Alert.OK);
				return;
			}
		}
	} else {
		amfWriter = new AMF();
		amfWriter.addEventListener(Event.COMPLETE, saveCompleteHandler, false, 0, true);
		if (CONFIG::debugging == true) {
			amfWriter.serialize(systemManager, o, nVersion);
		} else {
			try {
				amfWriter.serialize(systemManager, o, nVersion);
			} catch (e:Error) {
				Alert.show(e.message, 'Error Saving', Alert.OK);
				return;
			}
		}
	}
}

private function saveCompleteHandler(e:Event):void {
	if (solWriter) solWriter.removeEventListener(Event.COMPLETE, saveCompleteHandler);
	if (amfWriter) amfWriter.removeEventListener(Event.COMPLETE, saveCompleteHandler);
	
	var stream:FileStream = new FileStream();
	stream.openAsync(fileWrite, FileMode.WRITE);
	if(isSOL) {
		stream.writeBytes(solWriter.rawData);
	} else {
		stream.writeBytes(amfWriter.rawData);
	}
	stream.close();
	
	solWriter = null;
	amfWriter = null;
	
	// Clear message
	updateTreedataProvider(new ArrayCollection([{name:'Saved!'}]));
	
	// Open the new file
	if(fileRead.hasEventListener(Event.SELECT)) fileRead.removeEventListener(Event.SELECT, openHandler);
	fileRead = fileWrite;
	setTimeout(openHandler, 500);
}

// Fix JSON parsing associative arrays
private function JSONHelper(key:String, value:*):* {
	if (!value) return value;
	var typeName:String = describeType(value).@name.toString();
	if(typeName == "Array") {
		var isAssociative:Boolean = false;
		var o:Object = {};
		for (var k:String in value) {
			if (k != 'length' && isNaN(Number(k))) {
				isAssociative = true;
				o[k] = value[k];
			}
		}
		if (isAssociative) return o;
	}
	return value;
}

private function saveJSONHandler(e:Event = null):void {
	var o:Object = {};
	var a:Array = _dataProvider.source;
	var fileName:String = a[0].name;
	
	if((fileExport.extension == null || fileExport.extension.toLowerCase() != "json")) {
		fileExport.url += ".json";
	}
	
	if (CONFIG::debugging == true) {
		if(a[0].hasOwnProperty("children")) o = toObject(a[0].children, o);
	} else {
		try {
			if(a[0].hasOwnProperty("children")) o = toObject(a[0].children, o);
		} catch (err:Error) {
			Alert.show(err.message, 'Error Saving', Alert.OK);
			return;
		}
	}
	try {
	var strJSON:String = JSON.stringify(o, JSONHelper);
	var stream:FileStream = new FileStream();
	stream.openAsync(fileExport, FileMode.WRITE);
	stream.writeUTFBytes(strJSON);
	stream.close();
	
	Alert.show('File exported successfully', 'File Exported', Alert.OK);
	} catch(e:Error) {
		Alert.show('File failed to export', 'Export Error', Alert.OK);
		
	}
}

private function saveHandler(e:Event):void {
	// Force extension
	if(isSOL && (fileWrite.extension == null || fileWrite.extension.toLowerCase() != "sol")) {
		fileWrite.url += ".sol";
	} else if(!isSOL && (fileWrite.extension == null || fileWrite.extension.toLowerCase() != "amf")) {
		fileWrite.url += ".amf";
	}
	
	fileSave();
}

private function determineType(val:*):String {
	var type:String = typeof(val);
	
	if(type == "number") {
		if(nVersion == 3) {
			if(val %1 == 0 && (val < int.MAX_VALUE && val > int.MIN_VALUE)) {
			//if(val is int) {
			//	return "Integer";
			//} else if(val is uint) {
				return "Integer";
			} else {
				return "Number";
			}
		} else {
			return "Number";
		}
	} else if(type == "object") {
		if(val == null) {
			return "Null";
		} else if(val is Array) {
			return "Array";
		} else if(val is Date) {
			return "Date";
		} else if(val is XMLDocument) {
			return "XMLDocument";
		} else if(val is ByteArray) {
			return "ByteArray";
		} else if(val is Vector.<int>) {
			return 'Vector.<int>';
		} else if(val is Vector.<uint>) {
			return 'Vector.<uint>';
		} else if(val is Vector.<Number>) {
			return 'Vector.<Number>';
		} else if(val is Vector.<Object>) {
			return 'Vector.<Object>';
		} else if(val is Object) {
			return "Object";
		}
	} else if(type == "boolean") {
		return "Boolean";
	} else if(type == "string") {
		if(val == "__unsupported") return "Unsupported";
		return "String";
	} else if(type == "xml") {
		return "XML";
	}
	
	return "Undefined";
}

private function string2ByteArray(str:String):ByteArray {
	var arrBytes:Array = str.split(", ");
	var ba:ByteArray = new ByteArray();
	var l2:uint = arrBytes.length;
	for(var j:int = 0; j < l2; ++j) {
		ba[j] = Number("0x" + arrBytes[j]);
	}
	ba.position = 0;
	return ba;
}

private function byteArray2String(ba:ByteArray):String {
	var str:String = "";
	for(var i:int = 0; i < ba.length; i++) {
		var byte:String = Number(ba[i]).toString(16).toUpperCase();
		if(byte.length < 2) byte = "0" + byte;
		str += byte + ", ";
	}
	str = str.substring(0, (str.length - 2));
	return str;
}

private function inflateByteArray(e:Event, str:String):void {
	var ba:ByteArray = string2ByteArray(str);
	ba.inflate();
	
	byteValueInput.text = byteArray2String(ba);
	dataTree.selectedItem.value = byteValueInput.text;
	
	displayByteArray(ba);
}

private function deflateByteArray(e:Event, str:String):void {
	var ba:ByteArray = string2ByteArray(str);
	ba.deflate();
	
	byteValueInput.text = byteArray2String(ba);
	dataTree.selectedItem.value = byteValueInput.text;
	
	displayByteArray(ba);
}

private function displayByteArray(ba:ByteArray):void {
	// Unreliable since first three bits is common
	// Check if deflated/inflated
	/*ba.endian = Endian.LITTLE_ENDIAN; 
	var _bitBuffer:uint;
	var _bitPosition:int = 8;
	function readUB(numBits:int, ba:ByteArray):uint {
		var pos:uint = ba.position;
		ba.position = 0;
		var val:uint = 0;
		for(var i:int = 0; i < numBits; i++) {
			if (8 == _bitPosition) {
				_bitBuffer = ba.readUnsignedByte();
				_bitPosition = 0;
			}
			
			val |= (_bitBuffer & (0x01 << _bitPosition++) ? 1 : 0) << i;
		}
		ba.position = pos;
		return val;
	}
	var isFinal:uint = readUB(1, ba),
		type:uint = readUB(2, ba);
	
	switch(type) {
		case 0:
			trace("Stored");
			break;
		case 1:
			trace("Fixed Huffman codes");
			break;
		case 2:
			trace("Dynamic Huffman codes");
			break;
		case 3:
			trace("Reserved block type!!");
			break;
		default:
			trace("Unexpected value " + type + "!");
			break;
	}
	ba.endian = Endian.BIG_ENDIAN;*/
	//
	
	var pos:uint = ba.position;
	ba.position = 0;
	byteValueDisplay.text = ba.readUTFBytes(ba.length);
	ba.position = pos;
}

private function treeTip(item:Object):String {
	return item.type;
}

private function treeIcon(item:Object):Class {
	var iconClass:Class;
	var type:String = item.type;
	if (type && type.indexOf('Vector') != -1) type = 'Vector';
	switch(type) {
		case "Boolean":
			iconClass = booleanIcon;
			break;
		case "ByteArray":
			iconClass = bytearrayIcon;
			break;
		case "XMLDocument":
			iconClass = xmlIcon;
			break;
		case "XML":
			iconClass = xmlIcon;
			break;
		case "String":
			iconClass = stringIcon;
			break;
		case "Date":
			iconClass = dateIcon;
			break;
		case "Integer":
			iconClass = intIcon;
			break;
		case "Vector" :
			iconClass = vectorIcon;
			break;
		case "Null":
		case "Undefined":
		case "Unsupported":
			iconClass = undefinedIcon;
			break;
		case "Object":
			iconClass = objectIcon;
			break;
		case "Array":
			iconClass = arrayIcon;
			break;
		case "Number":
			iconClass = numberIcon;
			break;
		default:
			iconClass = null;
	}
    return iconClass;
}

private function treeLabel(item:Object):String {
	var strName:String = item.name || "No File Opened";
	return strName;
}

private function treeValueChanged(e:Event, type:String="invalid", value:* = null, hour:* = null, min:* = null, sec:* = null):void {
	if(hour != null) {
		var d:Date = value as Date;
		d.hours = hour;
		d.minutes = min;
		d.seconds = sec;
		dataTree.selectedItem.value = d;
	} else {
		dataTree.selectedItem.value = value;
	}
	
	if (type != 'invalid') {
		var isNewType:Boolean = (dataTree.selectedItem.type != type);
		dataTree.selectedItem.type = type;
		
		// update icon
		if (isNewType) {
			dataTree.iconField = "icon";
			treeChanged();
		}
	}
}

private function treeDoubleClick(e:ListEvent):void {
	isStartEdit = true;
	dataTree.editedItemPosition = {columnIndex:0, rowIndex:e.rowIndex};
}

private function treeKeyDown(e:KeyboardEvent):void {
	if (e.charCode == 127) { // Delete
		onClickRemove();
	}
}

private function treeEditBegin(e:ListEvent):void {
	if (!isStartEdit) {
		e.preventDefault();
		e.stopImmediatePropagation();
		e.stopPropagation();
		if (lastSelected) dataTree.selectedItem = lastSelected;
	}
	
	var item:TreeItemRenderer = e.itemRenderer as TreeItemRenderer;
	var listData:TreeListData = item.listData as TreeListData;
	// Check if has icon or not
	if(listData.icon) {
		dataTree.editorXOffset = 30;
	} else {
		dataTree.editorXOffset = 15;
	}
}

private function treeEditBeginning(e:ListEvent):void {
	lastSelected = dataTree.selectedItem;
	e.preventDefault(); 
}

private function treeEditEnd(e:ListEvent):void {
	isStartEdit = false;
	
	// Disable copying data back to the control
	e.preventDefault();
	
	// Get new value from editor
	var edited:TreeItemRenderer = dataTree.editedItemRenderer as TreeItemRenderer;
	edited.data.name = TextInput(dataTree.itemEditorInstance).text;
	
	// Update item label
	var listData:TreeListData = edited.listData as TreeListData;
	listData.label = edited.data.name;
	edited.invalidateProperties();
	
	// Close the cell editor
	dataTree.destroyItemEditor();
	
	// Notify the list control to update its display
	dataTree.dataProvider.notifyItemUpdate(edited);
}

private function treeChanged(e:Event = null):void {
	var selectedNode:Object = e ? Tree(e.target).selectedItem : dataTree.selectedItem;
	if(selectedNode.type != null) {
		showInspector = true;
		
		switch(selectedNode.type) {
			case "Integer":
				selectedNode.value = int(selectedNode.value);
			case "Number":
				numberValueInput.text = String(selectedNode.value);
				vsType.selectedChild = NumberType;
				//ddNumberType.selectedIndex = ArrayUtil.getItemIndex(selectedNode.type, arrDataTypes);
				break;
			case "Boolean":
				if(selectedNode.value == true) {
					radTrue.selected = true;
				} else {
					radFalse.selected = true;
				}
				vsType.selectedChild = BooleanType;
				//ddBooleanType.selectedIndex = 1;
				break;
			case "ByteArray":
				byteValueInput.text = String(selectedNode.value);
				vsType.selectedChild = ByteArrayType;
				
				var ba:ByteArray = string2ByteArray(byteValueInput.text);
				displayByteArray(ba);
				break;
			case "String":
			case "XML":
			case "XMLDocument":
				stringValueInput.text = String(selectedNode.value);
				vsType.selectedChild = StringType;
				//ddStringType.selectedIndex = ArrayUtil.getItemIndex(selectedNode.type, arrDataTypes);
				break;
			case "Date":
				var tempDate:Date = selectedNode.value as Date;
				dateDF.selectedDate = tempDate;
				//dateTS.timeValue = tempDate;
				txtHour.text = String(tempDate.hours);
				txtMin.text = String(tempDate.minutes);
				txtSec.text = String(tempDate.seconds);
				/*dateTS.hour = tempDate.hours;
                dateTS.minute = tempDate.minutes;
                dateTS.second = tempDate.seconds;*/
				vsType.selectedChild = DateType;
				//ddDateType.selectedIndex = 3;
				break;
			case "Null":
			case "Undefined":
				vsType.selectedChild = EmptyType;
				ddEmptyType.selectedIndex = ArrayUtil.getItemIndex(selectedNode.type, arrDataTypes);
				break;
			case "Array":
			case "Object":
			default:
				vsType.selectedChild = ObjectType;
				//ddObjectType.selectedIndex = ArrayUtil.getItemIndex(selectedNode.type, arrDataTypes);
				break;
		}
	}
}