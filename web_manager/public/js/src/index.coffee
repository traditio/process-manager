$ () ->
  $('.alert-message').delay(10000).fadeOut()
  $('#createProcessButton').click () ->
    $.facebox {
        div: '#createProcessForm',
    }
  $('.acts .link').click () ->
    confirm 'Вы уверены?'

  WEB_SOCKET_SWF_LOCATION = "/js/WebSocketMain.swf"

  ws = new WebSocket("ws://127.0.0.1:7002/")
  ws.onmessage = (e) ->
    json = jQuery.parseJSON( e.data )
    new EJS({url: '/js/templates/process_list.ejs'}).update 'processes_info', {data: json}

  ws.onclose = () ->
    alert 'Соединение с сервером разорвано! Перезагрузите страницу'


  $(".popup a.submit").live "click", (ev) ->
    ev.preventDefault()
    if $('.popup input[name="workers"]').val().match(/^\d+$/)
      $.get "/create/", $(".popup form").serialize(), (data) ->
        jQuery(document).trigger 'close.facebox'
    else
      $(".popup div.error").show().delay(10000).fadeOut()

  $(".acts .link").live "click", (ev) ->
    ev.preventDefault()
    $.get $(ev.target).attr("href")