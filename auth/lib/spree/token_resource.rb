module Spree
  module TokenResource
    module ClassMethods
      def token_resource
        has_one :tokenized_permission, :as => :permissable
        delegate :token, :to => :tokenized_permission, :allow_nil => true
        after_create :create_token
      end
    end

    def create_token
      create_tokenized_permission(:token => ::SecureRandom::hex(8))
      token
    end

    def self.included(receiver)
      receiver.extend ClassMethods
    end
  end
end
