require 'debci/db'
require 'debci/key'

module Debci
  class User < ActiveRecord::Base
    has_many :keys, class_name: 'Debci::Key'
  end
end
