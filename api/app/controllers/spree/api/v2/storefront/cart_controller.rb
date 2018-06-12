module Spree
  module Api
    module V2
      module Storefront
        class CartController < ::Spree::Api::V2::BaseController
          def create
            spree_authorize! :create, Spree::Order

            order = spree_current_order || dependencies[:create_cart].call(user: spree_current_user, store: spree_current_store).value
            render json: serialize_order(order), status: 201
          end

          def add_item
            variant = Spree::Variant.find(params[:variant_id])

            if spree_current_order.nil?
              render json: { error: "Order doesn't exist" }, status: 404
            else
              spree_authorize! :update, spree_current_order, order_token
              spree_authorize! :show, variant

              dependencies[:add_item_to_cart].call(order: spree_current_order, variant: variant, quantity: params[:quantity])
              render json: serialized_current_order, status: 200
            end
          end

          def remove_item
            if spree_current_order.nil?
              render json: { error: "Order doesn't exist" }, status: 404
            else
              line_item = spree_current_order.line_items.find(params[:line_item_id])

              spree_authorize! :update, spree_current_order, order_token

              dependencies[:remove_item_from_cart].call(order: spree_current_order, line_item: line_item)
              render json: serialized_current_order, status: 200
            end
          end

          private

          def dependencies
            {
              create_cart: Spree::Cart::Create,
              add_item_to_cart: Spree::Cart::AddItem,
              remove_item_from_cart: Spree::Cart::RemoveLineItem
            }
          end

          def serialized_current_order
            serialize_order(spree_current_order)
          end

          def serialize_order(order)
            Spree::V2::Storefront::CartSerializer.new(order.reload, include: [:line_items, :variants, :promotions]).serializable_hash
          end
        end
      end
    end
  end
end
