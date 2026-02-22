module Spree
  module Api
    module V3
      class ShippingMethodSerializer < BaseSerializer
        typelize name: :string, code: [:string, nullable: true]

        attributes :name, :code
      end
    end
  end
end
