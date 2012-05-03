window.WEB_SOCKET_SWF_LOCATION = "/js/WebSocketMain.swf";

window.WEB_SOCKET_DEBUG = true;

require({
    baseUrl: 'js',
    paths: {
        jquery: 'http://ajax.googleapis.com/ajax/libs/jquery/1.6.2/jquery.min'
    },
    priority: ['jquery']
}, ["text!templates/alert.ejs", "text!templates/process_list.ejs", "less", "ejs", "order!swfobject", "order!web_socket", "facebox", "init"], function() {
    return init_app();
});
