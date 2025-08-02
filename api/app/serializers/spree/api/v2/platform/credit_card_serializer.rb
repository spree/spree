module Spree
  module Api
    module V2
      module Platform
        class CreditCardSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :payment_method, serializer: Spree::Api::Dependencies.platform_payment_method_serializer.constantize
          belongs_to :user, serializer: Spree::Api::Dependencies.platform_user_serializer.constantize
        end
      end
    end
  end
end
