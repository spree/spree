module Spree
  module Api
    module V3
      module Admin
        class DeliveryMethodServiceSerializer < BaseSerializer
          typelize carrier: :string, service: :string, label: [:string, nullable: true],
                   markup_flat: [:string, nullable: true], markup_percent: [:string, nullable: true],
                   position: :number

          attributes :carrier, :service, :label

          attribute :markup_flat do |record|
            Spree::Money::Rounding.format(record.markup_flat, (current_store || Spree::Current.store)&.default_currency)
          end

          rate_attributes :markup_percent

          attributes :position
        end
      end
    end
  end
end
