require 'erubi'
require 'sinatra'
require 'erb'
require 'debci/user'

module Debci
  class App < Sinatra::Base
    set :erb, escape_html: true

    not_found do
      erb :not_found
    end

    include ERB::Util

    def self.get_page_range(current, total)
      full_range = (1..total)
      middle = ((current - 5)..(current + 5)).select { |i| full_range.include?(i) }
      start = middle.include?(1) ? [] : [1, nil]
      finish = middle.include?(total) ? [] : [nil, total]
      start + middle + finish
    end

    def get_page_range(current, total)
      self.class.get_page_range(current, total)
    end

    Page = Struct.new(:current_page, :records, :total_pages, :pages)

    def get_page_params(records, page, per_page_limit)
      current_page = page || 1
      records = records.page(current_page).per(per_page_limit)
      total_pages = records.total_pages
      pages = get_page_range(Integer(current_page), total_pages)
      Page.new(current_page, records, total_pages, pages)
    end
  end
end
