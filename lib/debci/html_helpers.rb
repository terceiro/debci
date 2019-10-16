module Debci
  module HTMLHelpers
    include ActiveSupport::NumberHelper

    ICONS = {
      pass: 'thumbs-up',
      neutral: 'minus-circle',
      fail: 'thumbs-down',
      fail_passed_never: ['thumbs-down', 'ban'],
      fail_passed_current: ['thumbs-down', 'bolt'],
      fail_passed_old: ['thumbs-down', 'arrow-down'],
      tmpfail_pass: 'thumbs-up',
      tmpfail_fail: 'thumbs-down',
      tmpfail: 'question-circle',
      no_test_data: 'question',
    }.freeze

    def icon(status)
      status ||= :no_test_data
      Array(ICONS[status.to_sym]).map do |i|
        "<i class='#{status} fa fa-#{i}'></i>"
      end.join(' ')
    end

    def filesize(filename, format)
      if File.exist?(filename)
        format % number_to_human_size(File.size(filename))
      end
    end
  end
end
