require "debci/app"
require "debci/package"
require 'debci/html_helpers'

module Debci
  class Frontend < Debci::App
    include Debci::HTMLHelpers
    set :views, "#{File.dirname(__FILE__)}/html/templates"

    get "/?" do
      redirect "/"
    end

    after do
      case response.status
      when 200
        cache_control :public, max_age: 5.minutes
      when 302
        cache_control :public, max_age: 1.year
      end
    end

    # Package search
    get '/-/search' do
      @query = params[:query]
      records = Debci::Package.where("name LIKE :query", query: "%#{@query}%").order(:name)

      # pagination
      results = get_page_params(records, params[:page], 10)

      erb :package_search_results, locals: { results: results }
    end

    # Package listing pages
    get "/:prefix/" do
      @package_prefixes = Debci::Package.prefixes
      @prefix = @moretitle = params[:prefix]
      @packages = Debci::Package.by_prefix(@prefix).order("name")
      erb :packagelist
    end
    get "/:prefix" do
      redirect "#{request.path}/"
    end

    # Package status pages
    get "/:prefix/:package/" do
      halt 404 unless params[:package].start_with?(params[:prefix])
      begin
        @package = Debci::Package.find_by_name!(params[:package])
      rescue ActiveRecord::RecordNotFound
        halt 404
      end
      @moretitle = @package.name
      erb :package
    end
    get "/:prefix/:package" do
      redirect "#{request.path}/"
    end

    # Package history pages
    get "/:prefix/:package/:suite/:architecture/" do
      halt 404 unless params[:package].start_with?(params[:prefix])
      package = Debci::Package.find_by_name(params[:package])
      @package = package
      @suite = params[:suite]
      @architecture = params[:architecture]
      @packages_dir = 'data/packages'
      @package_dir = File.join(@suite, @architecture, package.prefix, package.name)
      @site_url = expand_url(Debci.config.url_base, @suite)
      @artifacts_url_base = expand_url(Debci.config.artifacts_url_base, @suite)
      @moretitle = "#{package.name}/#{@suite}/#{@architecture}"
      @history = package.history(@suite, @architecture).reverse_order

      # pagination
      results = get_page_params(@history, params[:page], 500)

      erb :history, locals: { results: results }
    end
    get "/:prefix/:package/:suite/:architecture" do
      redirect "#{request.path}/"
    end
  end
end
