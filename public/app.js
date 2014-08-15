jQuery(function($) {

  var PACKAGES_HTML_DIR = '/data/.html/packages';
  var STATUS_DIR = '/data/status/';
  var STATUS_HTML_DIR = '/data/.html/status';

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

    $.get(STATUS_HTML_DIR + '/platforms.json', function(data) {
      $.each(data, function(index, item) {

        var platform = item.platform.replace('/', '-')

        $.get(STATUS_DIR + item.platform + '/history.json', function(data) {
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

          $.plot("#chart-pass-fail" + platform, status_data, {
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

          $.plot('#chart-pass-percentage' + platform, [pass_percentage], {
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

        })
      })
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
        $link.addClass(item.status[platform]);
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
      var MAX_ITEMS = 13;

      if (query.length > 0) {
        $('.request-search').hide();
        $('#package-select').show();
        var found = 0;
        $('#package-select li').each(function() {
          if ($(this).attr('data-package').match(query) && found <= MAX_ITEMS) {
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

  $(window).trigger('hashchange');

});
