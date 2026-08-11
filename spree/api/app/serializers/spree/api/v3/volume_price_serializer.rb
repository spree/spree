module Spree
  module Api
    module V3
      class VolumePriceSerializer < BaseSerializer
        typelize name: :string, min_quantity: :number, max_quantity: [:number, nullable: true], price: 'Price'

        attributes :name, :min_quantity, :max_quantity

        attribute :price do |tier|
          Spree.api.price_serializer.new(tier.price, params: params).to_h if tier.price.present?
        end
      end
    end
  end
end
