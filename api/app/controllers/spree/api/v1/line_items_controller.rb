module Spree
  module Api
    module V1
      class LineItemsController < Spree::Api::BaseController
        class_attribute :line_item_options

        self.line_item_options = []

        def new; end

        def create
          variant = Spree::Variant.find(params[:line_item][:variant_id])

          @line_item = Spree::Cart::AddItem.call(order: order,
                                                 variant: variant,
                                                 quantity: params[:line_item][:quantity],
                                                 options: line_item_params[:options]).value
          if @line_item.errors.empty?
            respond_with(@line_item, status: 201, default_template: :show)
          else
            invalid_resource!(@line_item)
          end
        end

        def update
          @line_item = find_line_item

          if Spree::Cart::Update.call(order: @order, params: line_items_attributes).success?
            @line_item.reload
            respond_with(@line_item, default_template: :show)
          else
            invalid_resource!(@line_item)
          end
        end

        def destroy
          @line_item = find_line_item
          Spree::Cart::RemoveLineItem.new.call(order: @order, line_item: @line_item)

          respond_with(@line_item, status: 204)
        end

        private

        def order
          @order ||= Spree::Order.includes(:line_items).find_by!(number: order_id)
          authorize! :update, @order, order_token
        end

        def find_line_item
          id = params[:id].to_i
          order.line_items.detect { |line_item| line_item.id == id } or
            raise ActiveRecord::RecordNotFound
        end

        def line_items_attributes
          { line_items_attributes: {
              id: params[:id],
              quantity: params[:line_item][:quantity],
              options: line_item_params[:options] || {}
          } }
        end

        def line_item_params
          params.require(:line_item).permit(:quantity, :variant_id, options: line_item_options)
        end
      end
    end
  end
end
