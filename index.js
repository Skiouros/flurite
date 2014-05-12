var db = require("./db").setup("", {});
var application = require("./application");

exports.db = db;
exports.application = application;
