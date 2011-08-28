(function() {
  $(function() {
    $('.alert-message').delay(10000).fadeOut();
    $('#createProcessButton').click(function() {
      return $.facebox({
        div: '#createProcessForm'
      });
    });
    return $('.acts .link').click(function() {
      return confirm('Вы уверены?');
    });
  });
}).call(this);
