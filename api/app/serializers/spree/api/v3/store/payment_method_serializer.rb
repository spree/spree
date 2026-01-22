module Spree
  module Api
    module V3
      module Store
        class PaymentMethodSerializer < BaseSerializer
          attributes :id, :name, :description, :type
        end
      end
    end
  end
end
