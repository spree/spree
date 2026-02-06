module Spree
  module Api
    module V3
      class PaymentMethodSerializer < BaseSerializer
        typelize name: :string, description: 'string | null', type: :string

        attributes :name, :description, :type
      end
    end
  end
end
