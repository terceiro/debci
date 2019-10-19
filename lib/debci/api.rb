require 'digest/sha1'
require 'fileutils'
require 'json'
require 'rdoc'
require 'securerandom'
require "sinatra/namespace"
require 'time'

require 'debci'
require 'debci/app'
require 'debci/job'
require 'debci/key'
require 'debci/test_handler'


class SelfDocAPI < Debci::App
  get '/doc' do
    @doc = self.class.doc
    erb :doc
  end
  class << self
    def doc(d=nil)
      @last_doc = format_doc(d)
      @doc ||= []
    end
    def register_doc(method, path)
      return unless @last_doc
      entry = {
        :method => method,
        :path => path,
        :text => @last_doc,
        :anchor => [method, path].join('_'),
      }
      @last_doc = nil
      doc.push(entry)
    end
    def format_doc(text)
      return nil unless text
      lines = text.lines
      if lines.first && lines.first.strip == ""
        lines.first.shift
      end
      lines.first =~ /^\s+/; prefix = $&
      if prefix
        lines.map! do |line|
          line.sub(/^#{prefix}/, '')
        end
      end
      formatter = RDoc::Markup::ToHtml.new(RDoc::Options.new, nil)
      RDoc::Markdown.parse(lines.join).accept(formatter)
    end

    def get(path, *args)
      register_doc('GET', path)
      super(path, *args)
    end
    def post(path, *args)
      register_doc('POST', path)
      super(path, *args)
    end
  end
end

module Debci

  class API < SelfDocAPI
    include Debci::TestHandler

    register Sinatra::Namespace
    set :views, File.dirname(__FILE__) + '/api'

    attr_reader :suite, :arch, :user

    before do
      @user = read_request_user
    end

    get '/' do
      redirect request.script_name + '/doc'
    end

    namespace '/v1' do

      doc <<-EOF
      * bli
      * bli
      * bli
      EOF

      doc <<-EOF
      This endpoint can be used to test your API key. It returns a 200 (OK)
      HTTP status if your API key is valid, and 403 (Forbidden) otherwise. The
      response also includes the username corresponding to the API key in the
      `Auth-User` header.
      EOF
      get '/auth' do
        authenticate_key!
        200
      end

      doc <<-EOF
      Displays a user-friendly HTML page that can be used by users to get an
      API key using this existing in-browser client certificate.

      This endpoint does not require an existing API key, but does require
      proper authentication with a client certificate (e.g.
      [Debian SSO](https://wiki.debian.org/DebianSingleSignOn)).
      EOF
      get '/getkey' do
        erb :getkey
      end

      doc <<-EOF
      Gets a new API key. Any existing API key is invalidated after a new one
      is obtained.

      This endpoint does not require an existing API key, but does require
      proper authentication with a client certificate (e.g.  [Debian
      SSO](https://wiki.debian.org/DebianSingleSignOn))
      EOF
      post '/getkey' do
        if @user
          key = Debci::Key.reset!(@user)
          headers['Content-Type'] = 'text/plain'
          [201, key.key]
        else
          403
        end
      end

      doc <<-EOF
      Presents a simple UI for retrying a test
      EOF
      get '/retry/:run_id' do
        if @user
          erb :retry
        else
          [403, erb(:cant_retry)]
        end
      end

      doc <<-EOF
      This endpoint can be used to reschedule a test that has already been
      performed, e.g. because the reason of the failure has been solved.

      URL parameters:

      * `:run_id`: which Job ID to retry
      EOF
      post '/retry/:run_id' do
        if not @user
          authenticate_key!
        end
        run_id = params[:run_id]
        begin
          j = Debci::Job.find(run_id)
        rescue ActiveRecord::RecordNotFound => error
          halt(400, "Job ID not known: #{run_id}")
        end
        job = Debci::Job.create!(
          package: j.package,
          suite: j.suite,
          arch: j.arch,
          requestor: j.requestor,
          trigger: j.trigger,
          pin_packages: j.pin_packages,
        )
        self.enqueue(job)

        201
      end

      doc <<-EOF
      Retrieves results for your test requests.

      Parameters:

      * `since`: UNIX timestamp; tells the API to only retrieve results that are
        newer then the given timestamp.

      Some test results may be updated after being created, for example while a test
      is still running, it will be returned, but it's status will be `null`. After it
      is completed, it will be updated to have the correct status.  So, if you are
      processing test results, make sure you support receiving the same result more
      than once, and updating the corresponding data on your side.

      The response is a JSON object containing the following keys:

      * `until`: UNIX timestamp that represents the timestamp of the latest results
        available. can be used as the `since` parameter in subsequent requests to
        limit the list of results to only the ones newer than it.
      * `results`: a list of test results, each of each will containing at least the
        following items:
        * `trigger`: the same string that was provided in the test submission. (string)
        * `package`: tested package (string)
        * `arch`: architecture where the test ran (string)
        * `suite`:  suite where the test ran (string)
        * `version`: version of the package that was tested (string)
        * `status`:  "pass", "fail", or "tmpfail" (string), or *null* if the test
          didn't finish yet.
        * `run_id`:  an id for the test run, generated by debci (integer)

      Note that this endpoint will only list requests that were made by the same API
      key that is being used to call it.

      Example:

      ```
      $ curl --header "Auth-Key: $KEY" https://host/api/v1/test?since=1508072999
      {
        "until": 1508159423,
        "results": [
          {
            "trigger": "foo/1.2",
            "package": "bar",
            "arch": "amd64",
            "suite": "testing",
            "version": "4.5",
            "status": "fail",
            "run_id": 12345
          },
          {
            "trigger": "foo/1.2",
            "package": "baz",
            "arch": "amd64",
            "suite": "testing",
            "version": "2.7",
            "status": "pass",
            "run_id": 12346
          }
        ]
      }
      ```
      EOF
      get '/test' do
        authenticate_key!
        jobs = Debci::Job.where(requestor: @user)
        if params[:since]
          since = Time.strptime(params[:since], '%s')
          jobs = jobs.where('updated_at >= ?', since)
        end
        data = {
          "until": jobs.map(&:created_at).max.to_i,
          "results": jobs,
        }
        headers['Content-Type'] = 'application/json'
        data.to_json
      end

      before '/test/:suite/:arch*'do
        authenticate_key!
        @suite = params[:suite]
        @arch = params[:arch]
        if !Debci.config.arch_list.include?(arch)
          halt(400, "Invalid architecture: #{arch}\n")
        elsif !Debci.config.suite_list.include?(suite)
          halt(400, "Invalid suite: #{suite}\n")
        end
      end

      doc <<-EOF
      ```
      EOF
      post '/test/batch' do
        test_requests = load_json(params[:tests])
        errors = validate_batch_test(test_requests)
        if errors.empty?
          request_batch_tests(test_requests, @user)
          201
        else
          halt(400, "Error: #{errors.join("\n")}")
        end
      end

      doc <<-EOF
      URL parameters:

      * `:suite`: which suite to test
      * `:arch`: which architecture to test

      Other parameters:

      * `tests`: a JSON object decribing the tests to be executed. This parameter can
        be either a file upload or a regular POST parameter.

      The `tests` JSON object must be an *Array* of objects. Each object represents a
      single test request, and can contain the following keys:

      * `package`: the (source!) package to be tested
      * `trigger`: a string that identifies the reason why this test is being
        requested. debci only stores this string, and it does not handle this in any
        special way.
      * `pin-packages`: an array describing packages that need to be obtained from
        different suites than the main one specified by the `suite` parameter. This
        is used e.g. to run tests on `testing` with a few packages from `unstable`,
        or on `unstable` with a few packages from `experimental`. Each item of the
        array is another array with 2 elements: the first is the package, and the
        second is the source. Examples:

          * `["foo", "unstable"]`: get `foo` from unstable
          * `["src:bar", "unstable"]`: get all binaries built from `bar` from unstable
          * `["foo,src:bar", "unstable"]`: get `foo` and all binaries built from `bar` from unstable

        Note: each suite can be only present once.

      In the example below, we are requesting to test `debci` and `vagrant` from
      testing, but with all binaries that come from the `ruby-defaults` source coming
      from unstable:

      ```
      $ cat tests.json
      [
        {
          "package": "debci",
          "trigger": "ruby/X.Y",
          "pin-packages": [
            ["src:ruby-defaults", "unstable"]
          ]
        },
        {
          "package": "vagrant",
          "trigger": "ruby/X.Y",
          "pin-packages": [
            ["src:ruby-defaults", "unstable"]
          ]
        }
      ]

      # tests as a file upload
      $ curl --header "Auth-Key: $KEY" --form tests=@tests.json \
          https://host/api/v1/test/testing/amd64

      # tests as a regular POST parameter
      $ curl --header "Auth-Key: $KEY" --data="$(cat tests.json)" \
          https://host/api/v1/test/testing/amd64
      ```
      EOF
      post '/test/:suite/:arch' do
        tests = load_json(params[:tests])
        self.request_tests(tests, suite, arch, @user)
        201
      end

      doc <<-EOF
      This is a shortcut to request a test run for a single package.

      URL parameters:

      * `:suite`: which suite to test
      * `:arch`: which architecture to test
      * `:package`: which (source!) package to test

      Example:

      ```
      $ curl --header "Auth-Key: $KEY" --data '' https://host/api/v1/test/unstable/amd64/debci
      ```
      EOF
      post '/test/:suite/:arch/:package' do
        pkg = params[:package]
        if Debci.blacklist.include?(pkg, suite: suite, arch: arch)
          halt(400, "Blacklisted package: #{pkg}\n")
        elsif ! valid_package_name?(pkg)
          halt(400, "Invalid package name: #{pkg}\n")
        end

        job = Debci::Job.create!(
            package: pkg,
            suite: params[:suite],
            arch: params[:arch],
            requestor: @user,
        )
        self.enqueue(job)

        201
      end

    end

    protected

    def __system__(*args)
      system(*args)
    end

    def load_json(param)
      begin
        raise "No tests" if param.nil?
        str = param.is_a?(Hash) && File.read(param[:tempfile]) || param
        JSON.load(str)
      rescue JSON::ParserError => error
        halt(400, "Invalid JSON: #{error}")
      rescue StandardError => error
        halt(400, "Error: #{error}")
      end
    end

    def authenticate_key!
      key = env['HTTP_AUTH_KEY']
      if key && @user = Debci::Key.authenticate(key)
        response['Auth-User'] = @user
      else
        halt(403, "Invalid key\n")
      end
    end

  end

end
