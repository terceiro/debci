jQuery(function($) {

  $.get('/data/packages.json', function(data) {
    $.each(data, function(index, item) {

      $('.packages').append("<a class='" + item.status + "' data-package='" + item.package + "'href='#" + item.package + "'>" + item.package + " (" + item.version  + ")</a> ");
    });

    if (window.location.hash != "") {
      pkg = window.location.hash.replace(/^#/, '');
      display_details(pkg);
    }
  });

  function display_details(pkg) {
    var pkg_dir = pkg.replace(/^((lib)?.)/, "$1/$&");
    var url = '/data/status/' + pkg_dir + '/history.json';

    $('.details').html('');
    $.get(url, function(history) {
      $('.details').append("<h1>Package: " + pkg + "</h1>");
      $('.details').append("<table><tr><th>Date</th><th>Status</th><th>Log</th></tr></table>");
      $.each(history, function(index, entry) {
        var log = '/data/log/' + pkg_dir + '/' + entry.date + ".txt";
        $('.details table').append("<tr><td>" + entry.date + "</td><td class='" + entry.status + "'>" + entry.status + "</td><td><a href='" + log + "'>view log</a></td></tr>")
      });
    });
  }

  $('.packages a').live('click', function() {
    var pkg = $(this).attr('data-package');
    display_details(pkg);
  });


});
