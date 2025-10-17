module Spree
  class LineItemsController < Spree::StoreController
    include CartMethods

    before_action :load_variant, only: :create
    before_action :assign_order_with_lock, except: :create
    before_action :load_line_item, except: :create

    skip_before_action :verify_authenticity_token, only: :create

    helper 'spree/products'

    def create
      @order    = current_order(create_order_if_necessary: true)
      @quantity = params[:quantity].to_i || 1
      options   = params[:options] || {}

      cookies.permanent.signed[:token] = { value: @order.token, domain: current_store.url_or_custom_domain } if @order.persisted?

      result = cart_add_item_service.call(order: @order,
                                          variant: @variant,
                                          quantity: @quantity,
                                          options: options)

      @line_item = result.value

      if result.success?
        load_line_items

        track_event('product_added', { line_item: @line_item })
      else
        @error = result.value.errors.full_messages.to_sentence
        flash.now[:error] = @error
      end

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to spree.cart_path(order_token: order_token) }
      end
    end

    def update
      quantity = line_item_params[:quantity]&.to_i || 1
      result = cart_set_item_quantity_service.call(order: @order, line_item: @line_item, quantity: quantity)

      if result.success?
        load_line_items
      else
        @error = result.value.errors.full_messages.to_sentence
        flash.now[:error] = @error
      end

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to spree.cart_path(order_token: order_token) }
      end
    end

    def destroy
      result = cart_remove_line_item_service.call(order: @order, line_item: @line_item)

      if result.success?
        load_line_items

        track_event('product_removed', { line_item: @line_item })
      else
        @error = result.value.errors.full_messages.to_sentence
        flash.now[:error] = @error
      end

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to spree.cart_path(order_token: order_token) }
      end
    end

    protected

    def load_variant
      @variant = current_store.variants.find(params[:variant_id])
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
