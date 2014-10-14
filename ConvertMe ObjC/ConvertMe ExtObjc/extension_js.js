var MMExtensionClass = function() {};

MMExtensionClass.prototype = {
    run: function(arguments) {
        alert("run");
        arguments.completionFunction({"content": document.body.innerHTML});
    },
    
    finalize: function(arguments) {
        alert("finalize");
        document.body.innerHTML = arguments["content"];
    }
};

var ExtensionPreprocessingJS = new MMExtensionClass;