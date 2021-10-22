module Spree
  module Api
    module V2
      module Platform
        class PriceSerializer < BaseSerializer
          include ResourceSerializerConcern

          attribute :display_price_including_vat_for do |price, params|
            price.display_price_including_vat_for(params[:price_options].presence || {})
          end

          attribute :display_compare_at_price_including_vat_for do |price, params|
            price.display_compare_at_price_including_vat_for(params[:price_options].presence || {})
          end
        end
      end
    end
  end
end
