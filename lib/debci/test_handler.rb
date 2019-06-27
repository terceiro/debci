module Debci
  module TestHandler
    def enqueue(job)
      priority = 1
      job.enqueue(priority)
    end

    def request_tests(tests, suite, arch, requestor)
      tests.each do |test|
        pkg = test['package']
        enqueue = true
        status = nil
        if Debci.blacklist.include?(pkg) || !Debci::API.valid_package_name?(pkg)
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
