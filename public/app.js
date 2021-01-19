jQuery(function($) {

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
      if (data.length < 2) {
        $('.chart-' + platform).html("Not enough data for plot. Wait until we get more data.");
      } else {
        var pass = [];
        var neutral = [];
        var fail = [];
        var tmpfail = [];
        var pass_percentage = [];
        var duration = [];
        var max_duration = 0;
        $.each(data, function(index, entry) {
          var date = Date.parse(entry.date);
          pass.push([date, entry.pass]);
          neutral.push([date, entry.neutral || 0]);
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
          label: "Neutral",
          data: neutral
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
          colors: [ '#8ae234', '#8080ff', '#ef2929', '#ffd862' ],
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

});
