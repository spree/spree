module Spree::TokenResource

  module ClassMethods
    def token_resource
      has_one :tokenized_permission, :as => :permissable
      delegate :token, :to => :tokenized_permission, :allow_nil => true
      after_create :create_token
    end
  end

  module InstanceMethods
    def create_token
      create_tokenized_permission(:token => ActiveSupport::SecureRandom::hex(8))
      token
    end
  end

  def self.included(receiver)
    receiver.extend ClassMethods
    receiver.send :include, InstanceMethods
  end

end