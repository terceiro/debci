require 'securerandom'
require 'digest/sha1'

require 'debci/db'

module Debci
  class Key < ActiveRecord::Base
    attr_accessor :key

    before_create do |key|
      key.key = SecureRandom.uuid
      key.encrypted_key = key.class.encrypt(key.key)
    end

    def self.reset!(username)
      find_by(user: username)&.destroy
      create!(user: username)
    end

    def self.authenticate(key)
      entry = find_by(encrypted_key: encrypt(key))
      entry&.user || nil
    end

    # Since the key being encrypt is random, there is no point is using salts
    # to protect against rainbow tables. So let's just use a good old SHA1
    # hash.
    def self.encrypt(key)
      Digest::SHA1.hexdigest(key)
    end
  end
end
