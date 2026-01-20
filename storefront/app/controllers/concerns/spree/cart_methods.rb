module Spree
  module CartMethods
    extend ActiveSupport::Concern

    included do
      before_action :merge_orders
      before_action :check_authorization
    end

    private

    def merge_orders
      current_order&.reload if set_current_order
    end

    def assign_order_with_lock
      @order = current_order(lock: true)
      unless @order
        flash[:error] = Spree.t(:order_not_found)
        redirect_to spree.cart_path(order_token: order_token) and return
      end
    end

    def check_authorization
      return if current_order.nil?

      authorize! :edit, current_order, order_token
    end

    def load_line_items
      @line_items = if @order.nil? || @order.new_record?
                      []
                    else
                      @order.line_items.includes(line_items_includes).order(created_at: :desc)
                    end
    end

    def line_items_includes
      {
        variant: [
          :images,
          :prices,
          { stock_items: :stock_location },
          { option_values: [:option_type] },
          {
            product: [
              { master: :images },
              { variants: :images }
            ]
          }
        ]
      }
    end
  end
end
