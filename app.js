jQuery(function($) {

  $.get('/data/packages.json', function(data) {
    $.each(data, function(index, item) {

      $('.packages').append("<a class='" + item.status + "' href='#" + item.package + "'>" + item.package + " (" + item.version  + ")</a> ");
    });

  });

  $(window).on('hashchange', function() {
    if (window.location.hash == "") {
      $('.details').html('');
    } else {
      pkg = window.location.hash.replace(/^#/, '');
      display_details(pkg);
    }
  });
  $(window).trigger('hashchange');

  function display_details(pkg) {
    var pkg_dir = pkg.replace(/^((lib)?.)/, "$1/$&");
    var url = '/data/status/' + pkg_dir + '/history.json';

    $('.details').html('');
    $.get(url, function(history) {
      $('.details').append("<h1>Package: " + pkg + "</h1>");

      $('.details').append("<table><tr><th>Version</th><th>Date</th><th>Duration</th><th>Status</th><th>Log</th></tr></table>");
      $.each(history, function(index, entry) {
        var log = '/data/log/' + pkg_dir + '/' + entry.date + ".log";
        $('.details table').append("<tr><td>" + entry.version + "</td><td>" + entry.date + "</td><td>" + entry.duration_human + "</td><td class='" + entry.status + "'>" + entry.status + "</td><td><a href='" + log + "'>view log</a></td></tr>")
      });

      var data_base = window.location.href.replace(/\/#.*/, '');
      var automation_info =
        "<p>Automate:</p>" +
        "<pre><code>" +
        "# latest status of the package\n" +
        "$ curl " + data_base + "/data/status/" + pkg_dir + '/latest.json\n' +
        "\n" +
        "# test run history of the package\n" +
        "$ curl " + data_base + "/data/status/" + pkg_dir + '/history.json\n' +
        "</code></pre>";
      $('.details').append(automation_info);

    }).fail(function() {
      $('.details').html(
        '<h1 class="fail">Package <em>' + pkg + '</em> not found</h1>');
    });
  }

});
