init_app = () ->
  $ () ->
    console.log 'init app'
    $('.alert-message').delay(10000).fadeOut()
    $('#createProcessButton').click () ->
      $.facebox { div: '#createProcessForm' }

    $('.acts .link').live 'click', (ev) ->
      ev.preventDefault()

      if confirm 'Вы уверены?'
        $.get $(ev.target).data('url'), {}, (data) ->
          if data.match(/^OK/)
            type = "success"
          else
            type = "error"
          new EJS({url: '/js/templates/alert.ejs'}).update 'alerts', {type: type, text: data}
          $('.alert-message').delay(10000).fadeOut()


    ws = new WebSocket("ws://localhost:10081/")
    ws.onopen = () ->
      console.log 'ws open'
    ws.onmessage = (e) ->
      json = jQuery.parseJSON( e.data )
      new EJS({url: '/js/templates/process_list.ejs'}).update 'processes_info', {data: json}
    ws.onclose = () ->
      alert 'Соединение с сервером разорвано! Перезагрузите страницу'

    $('form').live 'submit', () ->
      return false

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

window.init_app = init_app