require 'rss'

require 'debci'

module Debci
  class Feed
    def initialize(news)
      @feed = RSS::Maker.make('atom') do |feed|
        feed.channel.author = "#{distro_name} Continuous Integration"
        feed.channel.updated = news.first && news.first.date || Time.parse('2020-04-18T21:17:00 UTC')
        yield(feed) if block_given?
        insert_items(news, feed)
      end
    end

    def write(output)
      File.open(output, 'w') do |f|
        f.write(@feed.to_s.gsub('<summary>', '<summary type="html">'))
      end
    end

    private

    def insert_items(news, feed)
      news.each do |status|
        feed.items.new_item do |item|
          prefix = status.package.prefix
          item.link = "#{site_base}/data/packages/#{status.suite}/#{status.arch}/#{prefix}/#{status.package.name}/#{status.run_id}.log"
          item.title = status.headline
          item.date = status.date
          item.description = [
            "<p>#{status.headline}</p>",
            '<ul>',
            "<li>Version: #{status.version}</li>",
            "<li>Date: #{status.date}</li>",
            "<li>Test run duration: #{status.duration_human}</li>",
            "<li><a href=\"#{site_base}/packages/#{prefix}/#{status.package.name}/#{status.suite}/#{status.arch}\">Package history page</a></li>",
          ]

          item.description += [
            "<li><a href=\"#{artifacts_url(status)}/log.gz\">autopkgtest log</a></li>",
            "<li><a href=\"#{artifacts_url(status)}/artifacts.tar.gz\">autopkgtest artifacts</a></li>"
          ]

          item.description = item.description.compact.join("\n")
        end
      end
    end

    # expand {SUITE} macro in URLs
    def expand_url(url, suite)
      url&.gsub('{SUITE}', suite)
    end

    def artifacts_url(status)
      [
        expand_url(artifacts_url_base, status.suite),
        status.suite,
        status.arch,
        status.package.prefix,
        status.package.name,
        status.run_id,
      ].join('/')
    end

    def distro_name
      @distro_name ||= Debci.config.distro_name
    end

    def site_base
      @site_base ||= Debci.config.url_base
    end

    def artifacts_url_base
      @artifacts_url_base ||= Debci.config.artifacts_url_base || [site_base, 'data', 'autopkgtest'].join('/')
    end
  end
end
