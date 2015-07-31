cordova.define("com.star.printer.StarPrinter", function (require, exports, module) {
    function MyPrinter() { }

<<<<<<< .mine
    MyPrinter.prototype.CheckStatus = function (id, success, error) {
        //cordova.exec(success, error, 'Calendar', 'CheckStatus', [id]);
        cordova.exec(
          success, // success callback function
          error, // error callback function
          'StarPrinter', // mapped to our native Java class called "Calendar"
          'CheckStatus', // with this action name
          [id]                 // and this array of custom arguments to create our entry
      );
    };
               
    MyPrinter.prototype.CheckFirmwareVersion = function (id, success, error) {
        cordova.exec(success, error, 'StarPrinter', 'CheckFirmwareVersion', [id]);
    };
               
    MyPrinter.prototype.PrintSampleReceipt = function (id, success, error) {
        cordova.exec(success, error, 'StarPrinter', 'PrintSampleReceipt', [id]);
    };
               
    MyPrinter.prototype.PrintInvoice = function (invoice, sig, invoiceDetail, success, error) {
               cordova.exec(success, error, 'StarPrinter', 'PrintInvoice',
                            [invoice,sig,invoiceDetail]);
    };
    MyPrinter.prototype.PrintSignature = function (id, success, error) {
        cordova.exec(success, error, 'StarPrinter', 'PrintImage', id);
    };

=======
    MyPrinter.prototype.CheckStatus = function (id, success, error) {
        //cordova.exec(success, error, 'Calendar', 'CheckStatus', [id]);
        cordova.exec(
          success, // success callback function
          error, // error callback function
          'StarPrinter', // mapped to our native Java class called "Calendar"
          'CheckStatus', // with this action name
          [id]                 // and this array of custom arguments to create our entry
      );
    };
    MyPrinter.prototype.CheckFirmwareVersion = function (id, success, error) {
        cordova.exec(success, error, 'StarPrinter', 'CheckFirmwareVersion', [id]);
    };
    MyPrinter.prototype.PrintSampleReceipt = function (id, success, error) {
        cordova.exec(success, error, 'StarPrinter', 'PrintSampleReceipt', [id]);
    };
    MyPrinter.prototype.PrintInvoice = function (invoice, sig, invoiceDetail, success, error) {
    cordova.exec(success, error, 'StarPrinter', 'PrintInvoice', 
         [{                  // and this array of custom arguments to create our entry
             "invoice": invoice,
             "sig": sig,
             "invoiceDetail": invoiceDetail
         }]);
    };
    MyPrinter.prototype.PrintSignature = function (id, success, error) {
        cordova.exec(success, error, 'StarPrinter', 'PrintImage', id);
    };
>>>>>>> .theirs

module.exports = new MyPrinter();
});
