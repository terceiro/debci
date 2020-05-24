require 'securerandom'
require 'digest/sha1'

require 'debci/db'

module Debci
  class Key < ActiveRecord::Base
    belongs_to :user, class_name: 'Debci::User'

    attr_accessor :key

    before_create do |key|
      key.key = SecureRandom.uuid
      key.encrypted_key = key.class.encrypt(key.key)
    end

    def self.reset!(user)
      find_by(user: user)&.destroy
      create!(user: user)
    end

    def self.authenticate(key)
      entry = find_by(encrypted_key: encrypt(key))
      entry&.user || nil
    end

    # Since the key being encrypted is random, there is no point is using salts
    # to protect against rainbow tables. So let's just use a good old SHA1
    # hash.
    def self.encrypt(key)
      Digest::SHA1.hexdigest(key)
    end
  end
end
