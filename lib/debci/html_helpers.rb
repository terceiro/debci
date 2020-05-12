require 'erb'
require 'active_support'
require 'active_support/core_ext'

module Debci
  module HTMLHelpers
    include ERB::Util
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
      return nil unless File.exist?(filename)
      format % number_to_human_size(File.size(filename))
    end

    def title_test_trigger_pin(test)
      title = ''
      unless test.trigger.blank?
        title << "Trigger:\n"
        title << h(test.trigger)
      end
      if test.pinned?
        title << "\n\n"
        title << "Pinned packages:\n"
        title << expand_pin_packages(test)
      end
      title
    end

    def expand_pin_packages(test)
      return nil unless test.pinned?

      test.pin_packages.map do |packages, suite|
        packages.split(/\s*,\s*/).map do |pkg|
          "#{pkg} from #{suite}"
        end
      end.flatten.join("\n")
    end
  end
end
