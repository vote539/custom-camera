var CustomCamera = {
	getPicture: function(success, failure){
		cordova.exec(success, failure, "CustomCamera", "openCamera", []);
	}
};
module.exports = CustomCamera;