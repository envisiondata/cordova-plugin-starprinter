function StarPrinterPlugin() {}

StarPrinterPlugin.prototype.CheckStatus = function(id, success, error) {
  cordova.exec(success, error, 'StarPrinter', 'CheckStatus', [id]);
};

module.exports = new StarPrinterPlugin();