module Spree
  module Cart
    class RemoveLineItem
      prepend Spree::ServiceModule::Base

      def call(order:, line_item:, options: nil)
        options ||= {}
        ActiveRecord::Base.transaction do
          order.line_items.destroy(line_item)
          Spree::Dependencies.cart_recalculate_service.constantize.new.call(order: order,
                                                                            line_item: line_item,
                                                                            options: options)
        end
        success(line_item)
      end
    end
  end
end
