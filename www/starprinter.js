cordova.define("com.star.printer.StarPrinter", function (require, exports, module) {
               function StarPrinter() { }
               
               StarPrinter.prototype.CheckStatus = function (id, success, error) {
               cordova.exec(success, error, 'StarPrinter', 'CheckStatus', [id]);
               };
               
               StarPrinter.prototype.CheckFirmwareVersion = function (id, success, error) {
               cordova.exec(success, error, 'StarPrinter', 'CheckFirmwareVersion', [id]);
               };
               
               StarPrinter.prototype.PrintSampleReceipt = function (id, success, error) {
               cordova.exec(success, error, 'StarPrinter', 'PrintSampleReceipt', [id]);
               };
               

               StarPrinter.prototype.PrintSignature = function (id, success, error) {
               alert(id);
               cordova.exec(success, error, 'StarPrinter', 'PrintSignature', [id]);
               };
               
               module.exports = new StarPrinter();
               });