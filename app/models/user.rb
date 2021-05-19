require "openssl"
require "active_record"
require "coin"

class User < ActiveRecord::Base
  has_many :given_coins, :class_name => "Coin", :foreign_key => "sender_id"
  has_many :received_coins, :class_name => "Coin", :foreign_key => "receiver_id"

  attr_accessible :email, :name

  before_validation_on_create :setup_defaults

  private

  def validate
    errors.add_on_empty %w(email)
    errors.add("email", "has invalid format") unless email =~ /.*@.*\..*/
    if new_record? && User.count(["email = '%s'", email]) > 0 # `exists` does not yet exist
      errors.add("email", "already taken")
    end
  end

  def setup_defaults
    self.login_token = User.generate_login_token
    self.budget = 10
  end

  def self.generate_login_token
    OpenSSL::Random.random_bytes(20).unpack("H*").join
  end
end
