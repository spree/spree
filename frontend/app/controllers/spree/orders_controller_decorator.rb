module Spree
  module OrdersControllerDecorator
    def edit
      @order = current_order || Order.incomplete.
        includes(line_items: [variant: [:images, :product, option_values: :option_type]]).
        find_or_initialize_by(token: cookies.signed[:token])
      associate_user
    end
  end
end

::Spree::OrdersController.prepend ::Spree::OrdersControllerDecorator
