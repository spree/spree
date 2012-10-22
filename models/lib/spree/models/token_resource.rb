module Spree
  module Models
    module TokenResource
      module ClassMethods
        def token_resource
          has_one :tokenized_permission, :as => :permissable
          delegate :token, :to => :tokenized_permission, :allow_nil => true
          after_create :create_token
        end
      end

      def create_token
        permission = build_tokenized_permission
        permission.token = token = ::SecureRandom::hex(8)
        permission.save!
        token
      end

      def self.included(receiver)
        receiver.extend ClassMethods
      end
    end
  end
end

ActiveRecord::Base.class_eval { include Spree::Models::TokenResource }

