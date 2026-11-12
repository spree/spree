module Spree
  module Api
    module V3
      module Seller
        module Orders
          # Swapping goods on one of this seller's orders — a different size,
          # colour or product.
          #
          # The workflows are the operator's, shared through the concern. What
          # is here is what makes it the seller's: the order comes from
          # `current_seller_orders`, and the replacement variant is resolved
          # through `current_seller.variants` rather than the store's, because
          # a seller exchanges into their own catalogue and reaching a rival's
          # variant here would put that seller's stock on this seller's order.
          class ExchangesController < BaseController
            include Spree::Api::V3::Orders::ExchangeActions

            before_action :set_resource, only: [:show, :approve, :receive, :fulfill, :cancel]

            request_params :exchange do |body|
              body.attribute :items, :array, required: true do |item|
                item.attribute :fulfillment_item_id, :id, required: true
                item.attribute :new_variant_id, :id, required: true, description: "One of this seller's own variants."
                item.attribute :quantity, :integer, required: true
              end
              body.attribute :reason_id, :id, nullable: true
              body.attribute :stock_location_id, :id,
                nullable: true,
                description: "One of this seller's own stock locations, where the goods are restocked."
              body.attribute :memo, :string, nullable: true
            end

            request_params 'ExchangeReceiveParams', action: :receive do |body|
              body.attribute :items, :array,
                description: 'What actually arrived. Omit to receive everything as requested and resellable.' do |item|
                item.attribute :exchange_line_item_id, :id, required: true
                item.attribute :quantity, :integer, required: true
                item.attribute :resellable, :boolean,
                  description: 'Goods that cannot be resold are received but never restocked. Defaults to true.'
              end
            end

            request_params 'ExchangeCancelParams', action: :cancel do |body|
              body.attribute :reason, :string, description: 'A note on why the exchange was canceled.'
            end

            request_params 'ExchangeFulfillParams', action: :fulfill do |body|
              body.attribute :refund_method, :string,
                choices: %w[original_payment store_credit],
                description: 'Defaults to `store_credit`.'
            end

            protected

            def serializer_class
              Spree.api.seller_exchange_serializer
            end

            def collection_includes
              [:reason, :stock_location,
               { exchange_line_items: [:original_variant, :new_variant, :line_item] }]
            end

            private

            # The seller's own catalogue and their own shelves — a rival's
            # variant is not theirs to send, nor a marketplace warehouse
            # theirs to restock.
            def replacement_variant_for(variant_id)
              current_seller.variants.find_by_prefix_id!(variant_id)
            end

            def stock_location_for_create
              return nil if create_params[:stock_location_id].blank?

              current_seller.stock_locations.find_by_prefix_id!(create_params[:stock_location_id])
            end
          end
        end
      end
    end
  end
end
