module Spree
  module Api
    module V3
      module Admin
        class DeliveryMethodServiceSerializer < BaseSerializer
          typelize carrier: :string, service: :string, label: [:string, nullable: true],
                   markup_flat: [:string, nullable: true], markup_percent: [:string, nullable: true],
                   position: :number

          attributes :carrier, :service, :label, :markup_flat, :markup_percent, :position
        end
      end
    end
  end
end
