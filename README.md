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

To print a signature:
•	plugin.printer.PrintSignature($('#sig').signature('toJSON'));
•	The json structure of the signature comes form this example.
  o	http://keith-wood.name/signature.html
