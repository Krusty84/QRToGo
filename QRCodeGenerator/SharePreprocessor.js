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
