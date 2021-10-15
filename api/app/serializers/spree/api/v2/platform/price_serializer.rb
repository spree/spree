module Spree
  module Api
    module V2
      module Platform
        class PriceSerializer < BaseSerializer
          include ResourceSerializerConcern

          attribute :display_price_including_vat_for do |price|
            price.display_price_including_vat_for({})
          end

          attribute :display_compare_at_price do |price|
            price.display_price_including_vat_for({})
          end

          attribute :display_compare_at_price_including_vat_for do |price|
            price.display_compare_at_price_including_vat_for({})
          end
        end
      end
    end
  end
end
