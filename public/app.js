jQuery(function($) {

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

  on('', function() {
    $('.details').html('');
    $.get('data/status/history.json', function(data) {

      var pass = [];
      $.each(data, function(index, entry) {
        pass.push([Date.parse(entry.date), entry.pass]);
      });

      var fail = [];
      $.each(data, function(index, entry) {
        fail.push([Date.parse(entry.date), entry.fail]);
      });

      //alert(pass);
      //alert(fail);
      var data = [ { label: "Pass", data: pass }, { label: "Fail", data: fail }];

      $.plot("#chart", data, {
        series: {
          stack: true,
          lines: {
            show: true,
            fill: true,
            steps: false,
          }
        },
        colors: [ '#8ae234', '#ef2929' ],
        legend: {
          show: true,

        },
        xaxis: {
          mode: "time"
        },
        yaxis: {
          min: 0
        }
      });

    })
  });

  match(/^#package\/(\S+)$/, function(params) {
    var pkg = params[1];
    display_details(pkg);
  });


  $.get('data/packages.json', function(data) {
    $.each(data, function(index, item) {

      $('.packages').append("<a class='" + item.status + "' href='#package/" + item.package + "'>" + item.package + " (" + item.version  + ")</a> ");
    });

  });

  function display_details(pkg) {
    var pkg_dir = pkg.replace(/^((lib)?.)/, "$1/$&");
    var url = 'data/packages/' + pkg_dir + '/history.json';

    $('.details').html('');
    $.get(url, function(history) {
      $('.details').append("<h1>Package: " + pkg + "</h1>");

      $('.details').append("<table><tr><th>Version</th><th>Date</th><th>Duration</th><th>Status</th><th>Log</th></tr></table>");
      $.each(history, function(index, entry) {
        var log = 'data/packages/' + pkg_dir + '/' + entry.date + ".log";
        $('.details table').append("<tr><td>" + entry.version + "</td><td>" + entry.date + "</td><td>" + entry.duration_human + "</td><td class='" + entry.status + "'>" + entry.status + "</td><td><a href='" + log + "'>view log</a></td></tr>")
      });

      var data_base = window.location.href.replace(/\/#.*/, '');
      var automation_info =
        "<p>Automate:</p>" +
        "<pre><code>" +
        "# latest status of the package\n" +
        "$ curl " + data_base + "/data/packages/" + pkg_dir + '/latest.json\n' +
        "\n" +
        "# test run history of the package\n" +
        "$ curl " + data_base + "/data/packages/" + pkg_dir + '/history.json\n' +
        "</code></pre>";
      $('.details').append(automation_info);

    }).fail(function() {
      $('.details').html(
        '<h1 class="fail">Package <em>' + pkg + '</em> not found</h1>');
    });
  }

  $(window).trigger('hashchange');

});
