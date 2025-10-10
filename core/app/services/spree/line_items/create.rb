module Spree
  module LineItems
    class Create
      prepend Spree::ServiceModule::Base
      include Helper

      def call(order:, line_item_attributes: {}, options: {})
        line_item = order.line_items.new(line_item_attributes)

        ActiveRecord::Base.transaction do
          return failure(line_item) unless line_item.save

          recalculate_service.call(order: order, line_item: line_item, options: options)
        end

        success(line_item)
      end
    end
  end
end
