require 'debci/job'

module Debci
  module TestHandler
    def enqueue(job)
      priority = 1
      job.enqueue(priority)
    end

    def valid_package_name?(pkg)
      pkg =~ /^[a-z0-9][a-z0-9+.-]+$/
    end

    def request_batch_tests(test_requests, requestor)
      test_requests.each do |request|
        request['arch'].each do |arch|
          request_tests(request['tests'], request['suite'], arch, requestor)
        end
      end
    end

    def validate_batch_test(test_requests)
      errors = []
      errors.push("Not an array") unless test_requests.is_a?(Array)
      test_requests.each_with_index do |request, index|
        request_suite = request['suite']
        errors.push("No suite at request index #{index}") if request_suite == ''
        errors.push("Wrong suite (#{request_suite}) at request index #{index}, available suites: #{Debci.config.suite_list.join(', ')}") unless Debci.config.suite_list.include?(request_suite)
        archs = request['arch'].reject(&:empty?)
        errors.push("No archs are specified at request index #{index}") if archs.empty?
        errors.push("Wrong archs (#{archs.join(', ')}) at request index #{index}, available archs: #{Debci.config.arch_list.join(', ')}") if (Debci.config.arch_list & archs).length != archs.length
        request['tests'].each_with_index do |t, i|
          errors.push("Invalid package name at request index #{index} and test index #{i}") unless valid_package_name?(t['package'])
        end
      end
      errors
    end

    def request_tests(tests, suite, arch, requestor)
      tests.each do |test|
        pkg = test['package']
        enqueue = true
        status = nil
        if Debci.blacklist.include?(pkg) || !valid_package_name?(pkg)
          enqueue = false
          status = 'fail'
        end

        job = Debci::Job.create!(
          package: test['package'],
          suite: suite,
          arch: arch,
          requestor: requestor,
          status: status,
          trigger: test['trigger'],
          pin_packages: test['pin-packages']
        )
        self.enqueue(job) if enqueue
      end
    end
  end
end
