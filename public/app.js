jQuery(function($) {

  // FIXME generalize this later
  var PACKAGES_DIR = '/data/packages/unstable/amd64';
  var PACKAGES_HTML_DIR = '/data/.html/packages';
  var AUTOPKGTEST_DIR = '/data/autopkgtest/unstable/amd64';
  var STATUS_DIR = '/data/status/unstable/amd64';

  var handlers = {};
  function on(hash, f) {
    handlers[hash] = f;
  }
  var patterns = [];
  function match(pattern, f) {
    patterns.push([pattern, f]);
  }

  $(window).on('hashchange', function() {
    var hash = window.location.hash;
    if (handlers[hash]) {
      handlers[hash]();
    } else {
      for (i in patterns) {
        var p = patterns[i][0];
        var h = patterns[i][1];
        var match = hash.match(p);
        if (match) {
          h(match);
          return;
        }
      }
    }
  });

  function switch_to(id) {
    $('#main > div').hide();
    $(id).show()
  }

  on('', function() {
    switch_to('#status');

    $.get(STATUS_DIR + '/history.json', function(data) {

      if (data.length < 2) {
        $('.chart').html("Not enough data for plot. Wait until the next run");
        return;
      }

      var pass = [];
      var fail = [];
      var tmpfail = [];
      var pass_percentage = [];
      var duration = [];
      var max_duration = 0;
      $.each(data, function(index, entry) {
        var date = Date.parse(entry.date);
        pass.push([date, entry.pass]);
        fail.push([date, entry.fail]);
        tmpfail.push([date, entry.tmpfail || 0]);
        pass_percentage.push([date, entry.pass / entry.total]);
        duration.push([date, entry.duration]);
        if (entry.duration && entry.duration > max_duration) {
          max_duration = entry.duration;
        }
      });

      var status_data = [
        {
          label: "Pass",
          data: pass
        },
        {
          label: "Fail",
          data: fail
        },
        {
          label: "Temporary failure",
          data: tmpfail
        }
      ];

      $.plot("#chart-pass-fail", status_data, {
        series: {
          stack: true,
          lines: {
            show: true,
            fill: true,
            steps: false,
          }
        },
        colors: [ '#8ae234', '#ef2929', '#ffd862' ],
        legend: {
          show: true,
          backgroundOpacity: 0.2,
          position: 'sw'
        },
        xaxis: {
          mode: "time"
        },
        yaxis: {
          min: 0
        }
      });

      $.plot('#chart-pass-percentage', [pass_percentage], {
        series: {
          lines: {
            show: true
          }
        },
        colors: [ '#8ae234' ],
        xaxis: {
          mode: 'time',
        },
        yaxis: {
          min: 0,
          max: 1,
          ticks: [[0.25, '25%'], [0.5, '50%'], [0.75, '75%'], [1.0, '100%']]
        }
      });

      var max_hours = Math.round(max_duration / 3600) + 1;
      var step = Math.ceil(max_hours / 10);
      max_hours = step * 10;
      var duration_ticks = [];
      for (var i = 0; i <= max_hours; i = i + step) {
        duration_ticks.push([i * 3600, i + 'h']);
      }
      $.plot('#chart-run-duration', [duration], {
        series: {
          bars: {
            show: true
          }
        },
        xaxis: {
          mode: 'time',
        },
        yaxis: {
          min: 0,
          ticks: duration_ticks
        }
      });

    })
  });

  on('#packages', function() {
    switch_to('#packages');
    $('#package-search').focus();
  });

  match(/^#package\/(\S+)$/, function(params) {
    switch_to('#packages');

    var pkg = params[1];
    display_details(pkg);
  });


  $.get(PACKAGES_HTML_DIR + '/packages.json', function(data) {
    $.each(data, function(index, item) {
      var package_dir = item.package.replace(/^((lib)?.)/, "$1/$&");

      var $link = $('<a></a>');
      $link.attr('href', 'packages/' + package_dir);
      $link.html(item.package + ' ' + '<b>Package page</b>');

      var $list_item = $('<li></li>');
      $list_item.attr('data-package', item.package + ' ' + 'Package page');
      $list_item.append($link);

      $('#package-select').append($list_item);

      var available_platforms = item.platforms;

      for (var platform in available_platforms) {
        $link = $('<a></a>');
        $link.attr('href', 'packages/' + package_dir + '/' + available_platforms[platform]);
        $link.html(item.package + ' <b>' + available_platforms[platform] + '</b>');

        $list_item = $('<li></li>');
        $list_item.attr('data-package', item.package + ' ' + available_platforms[platform]);
        $list_item.append($link);

        $('#package-select').append($list_item);
      }

    });

    $('#package-select').hide();
  });

  $('#package-search').keyup(function() {
      var query = $(this).val();
      if (query.length > 0) {
        $('.request-search').hide();
        $('#package-select').show();
        var found = 0;
        $('#package-select li').each(function() {
          if ($(this).attr('data-package').match(query)) {
            $(this).show();
            found++;
          } else {
            $(this).hide();
          }
        });
        $('.search-count .count').html(found);
        $('.search-count').show();
      } else {
        $('.request-search').show();
        $('.search-count').hide();
        $('#package-select li').hide();
      }
  });

  function display_details(pkg) {
    var pkg_dir = pkg.replace(/^((lib)?.)/, "$1/$&");
    var url = PACKAGES_DIR + '/' + pkg_dir + '/history.json';

    var $target = $('#package-details')
    $target.html('');
    $.get(url, function(history) {
      var feed_url = 'data/feeds/' + pkg_dir + '.xml';
      var feed = "&nbsp;<a href=\"" + feed_url + "\" title=\"Atom feed for " + pkg + "\"><span class='fa fa-rss'></span></a>";
      $target.append("<h1>" + pkg + feed + "</h1>");

      if (history[0]) {
        $('#package-details h1').addClass(history[0].status);
      }

      var $table = $("<table>");
      $table.addClass('table table-condensed');

      var $header = $("<tr>");
      $header.append($('<th>').html('Version'));
      $header.append($('<th>').html('Date'));
      $header.append($('<th>').html('Duration'));
      $header.append($('<th>').html('Status'));
      $header.append($('<th colspan="3">').html('Results'));
      $table.append($header);

      $.each(history, function(index, entry) {
        var run_id = (entry.run_id || entry.date);
        var debci_log = PACKAGES_DIR + '/' + pkg_dir + '/' + run_id  + ".log";
        var adt_log = PACKAGES_DIR + '/' + pkg_dir + '/' + run_id  + ".autopkgtest.log";
        var artifacts = AUTOPKGTEST_DIR + '/' + pkg_dir + '/' + run_id;

        var $row = $('<tr>');
        $row.append($('<td>').html(entry.version));
        $row.append($('<td>').html(entry.date));
        $row.append($('<td>').html(entry.duration_human));
        $row.append($('<td>').html(entry.status).addClass(entry.status));
        $row.append($('<td>').html($('<a>').attr('href', debci_log).html('debci log')));
        $row.append($('<td>').html($('<a>').attr('href', adt_log).html('test log')));
        $row.append($('<td>').html($('<a>').attr('href', artifacts).html('artifacts')));

        $table.append($row);
      });
      $target.append($table);

      var data_base = window.location.href.replace(/\/[#?].*/, '');
      var automation_info =
        "<p>Automate:</p>" +
        "<pre><code>" +
        "# latest status of the package\n" +
        "$ curl " + data_base + "/" + PACKAGES_DIR + "/" + pkg_dir + '/latest.json\n' +
        "\n" +
        "# latest autopkgtest log of the package\n" +
        "$ curl " + data_base + "/" + PACKAGES_DIR + "/" + pkg_dir + '/latest-autopkgtest/log\n' +
        "\n" +
        "# test run history of the package\n" +
        "$ curl " + data_base + "/" + PACKAGES_DIR + "/" + pkg_dir + '/history.json\n' +
        "</code></pre>";
      $target.append(automation_info);

    }).fail(function() {
      $target.html(
        '<h1 class="fail">Package <em>' + pkg + '</em> not found</h1>');
    });
  }

  $(window).trigger('hashchange');

});
