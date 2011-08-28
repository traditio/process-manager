(function() {
  $(function() {
    var WEB_SOCKET_SWF_LOCATION, ws;
    $('.alert-message').delay(10000).fadeOut();
    $('#createProcessButton').click(function() {
      return $.facebox({
        div: '#createProcessForm'
      });
    });
    $('.acts .link').click(function() {
      return confirm('Вы уверены?');
    });
    WEB_SOCKET_SWF_LOCATION = "/js/WebSocketMain.swf";
    ws = new WebSocket("ws://127.0.0.1:7002/");
    ws.onmessage = function(e) {
      var json;
      json = jQuery.parseJSON(e.data);
      return new EJS({
        url: '/js/templates/process_list.ejs'
      }).update('processes_info', {
        data: json
      });
    };
    ws.onclose = function() {
      return alert('Соединение с сервером разорвано! Перезагрузите страницу');
    };
    $(".popup a.submit").live("click", function(ev) {
      ev.preventDefault();
      if ($('.popup input[name="workers"]').val().match(/^\d+$/)) {
        return $.get("/create/", $(".popup form").serialize(), function(data) {
          return jQuery(document).trigger('close.facebox');
        });
      } else {
        return $(".popup div.error").show().delay(10000).fadeOut();
      }
    });
    return $(".acts .link").live("click", function(ev) {
      ev.preventDefault();
      return $.get($(ev.target).attr("href"));
    });
  });
}).call(this);
