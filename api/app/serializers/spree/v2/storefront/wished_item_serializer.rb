module Spree
  module V2
    module Storefront
      class WishedItemSerializer < BaseSerializer
        set_type :wished_item

        attributes :quantity

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
