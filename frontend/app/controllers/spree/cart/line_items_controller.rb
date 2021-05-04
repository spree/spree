module Spree
  module Cart
    class LineItemsController < Spree::StoreController
      include ::Spree::CartMethods

      before_action :load_variant, only: :create
      before_action :assign_order_with_lock, except: :create
      before_action :load_line_item, except: :create

      helper 'spree/products'

      respond_to :html

      def create
        @order   = current_order(create_order_if_necessary: true)
        quantity = params[:quantity].to_i || 1
        options  = params[:options] || {}

        result = cart_add_item_service.call(order: @order,
                                            variant: @variant,
                                            quantity: quantity,
                                            options: options)

        flash.now[:error] = result.value.errors.full_messages.to_sentence if result.failure?

        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to spree.cart_path }
        end
      end

      def update
        quantity = line_item_params[:quantity]&.to_i || 1
        result = cart_set_item_quantity_service.call(order: @order, line_item: @line_item, quantity: quantity)

        @error = result.value.errors.full_messages.to_sentence if result.failure?

        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to spree.cart_path }
        end
      end

      def destroy
        cart_remove_line_item_service.call(order: @order, line_item: @line_item)

        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to spree.cart_path }
        end
      end

      protected

      def load_variant
        @variant = Spree::Variant.find(params[:variant_id])
      end

      def load_line_item
        @line_item = @order.line_items.find(params[:id])
      end

      def line_item_params
        params.require(:line_item).permit(*permitted_line_item_attributes)
      end

      def cart_add_item_service
        Spree::Dependencies.cart_add_item_service.constantize
      end

      def cart_remove_line_item_service
        Spree::Dependencies.cart_remove_line_item_service.constantize
      end

      def cart_set_item_quantity_service
        Spree::Dependencies.cart_set_item_quantity_service.constantize
      end
    end
  end
end
