var init_app;

init_app = function() {
    return $(function() {
        var ws;
        $('.alert-message').delay(10000).fadeOut();
        $('#createProcessButton').click(function() {
            return $.facebox({
                div: '#createProcessForm'
            });
        });
        $('.acts .link').live('click', function(ev) {
            ev.preventDefault();
            if (confirm('Are you sure?')) {
                return $.get($(ev.target).data('url'), {}, function(data) {
                    var type;
                    if (data.match(/^OK/)) {
                        type = "success";
                    } else {
                        type = "error";
                    }
                    new EJS({
                        url: '/js/templates/alert.ejs'
                    }).update('alerts', {
                        type: type,
                        text: data
                    });
                    return $('.alert-message').delay(10000).fadeOut();
                });
            }
        });
        ws = new WebSocket("ws://localhost:10081/");
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
            return alert('Cannot connect to the server. Refresh the page');
        };
        $('form').live('submit', function() {
            return false;
        });
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
};

window.init_app = init_app;