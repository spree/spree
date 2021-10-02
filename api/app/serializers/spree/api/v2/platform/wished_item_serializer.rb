module Spree
  module Api
    module V2
      module Platform
        class WishedItemSerializer < BaseSerializer
          include ResourceSerializerConcern

          attribute :price do |wished_item, params|
            wished_item.price(currency: params[:currency])
          end

          attribute :total do |wished_item, params|
            wished_item.total(currency: params[:currency])
          end

          attribute :display_price do |wished_item, params|
            wished_item.display_price(currency: params[:currency]).to_s
          end

          attribute :display_total do |wished_item, params|
            wished_item.display_total(currency: params[:currency]).to_s
          end

          belongs_to :variant
        end
      end
    end
  end
end
