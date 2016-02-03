# cordova-plugin-starprinter
Cordova/PhoneGap plugin for the Star Bluetooth printer SM-T300I.


# Installing
This plugin follows the Cordova 3.0+ plugin spec, so it can be installed through the Cordova CLI in your existing Cordova project:
cordova plugin add https://github.com/envisiondata/cordova-plugin-starprinter.git

# JavaScript Usage

To check the status of the printer:

•	plugin.printer.CheckStatus();

To check the Firmware Version of the printer:

•	plugin.printer.CheckFirmwareVersion();

To print a sample receipt:

•	plugin.printer.PrintSampleReceipt();
    
    This will print the 3" sample from the Star Developer Kit.

To print a signature:
    
    var success = function () { alert("Success"); };
    var error = function (message) { alert("Oopsie! " + message); };
    plugin.printer.PrintSignature($('#sig').signature('toJSON'), success, error);

•	The json structure of the signature comes form this example.

  o	http://keith-wood.name/signature.html


# Important

If you change this plugin, next time you update any plugin your changes will be overwritten. You need to figure out how to disable auto updates.
