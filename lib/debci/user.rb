require 'debci/db'
require 'debci/key'

module Debci
  class User < ActiveRecord::Base
    has_many :keys, class_name: 'Debci::Key'
    has_many :jobs, class_name: 'Debci::Job'
  end
end
