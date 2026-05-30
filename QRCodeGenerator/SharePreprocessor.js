//
//  SharePreprocessor.js
//  QRToGo
//
//  Created by Sedoykin Alexey on 26/05/2026.
//

var SharePreprocessor = function() {};

SharePreprocessor.prototype = {
    run: function(arguments) {
        arguments.completionFunction({
            pageURL: document.URL || "",
            pageTitle: document.title || ""
        });
    }
};

var ExtensionPreprocessingJS = new SharePreprocessor();
