jQuery(function($) {

  var PACKAGES_HTML_DIR = '/data/.html/packages';

  function pkg_dir(pkg) {
    return pkg.replace(/^((lib)?.)/, "$1/$&");
  }

  function on(selector, handler) {
    if ($.find(selector).length > 0) {
      handler();
    }
  }

  on('#status', function() {
    $('meta[name*=data-]').each(function() {
      var platform = $(this).attr('name').replace('data-', '');
      var json = $('meta[name=data-' + platform + ']').attr("content");
      var data = $.parseJSON(json);
      console.log(platform + ' data: ' + data);
      if (data.length < 2) {
        $('.chart-' + platform).html("Not enough data for plot. Wait until we get more data.");
        console.log('skipping ' + platform + '...')
      } else {
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

        $.plot("#chart-pass-fail-" + platform, status_data, {
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

        $.plot('#chart-pass-percentage-' + platform, [pass_percentage], {
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
      }
    });
  });

  if (window.location.pathname == '/') {
    var match = window.location.hash.match(/^#package\/(\S+)$/);
    if (match) {
      var pkg = match[1];
      window.location.href = '/packages/' + pkg_dir(pkg);
    }
  }

});
