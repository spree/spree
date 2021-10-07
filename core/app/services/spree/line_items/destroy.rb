module Spree
  module LineItems
    class Destroy
      prepend Spree::ServiceModule::Base
      include Helper

      def call(line_item:, options: {})
        order = line_item.order

        ActiveRecord::Base.transaction do
          line_item.destroy!
          recalculate_service.call(order: order, line_item: line_item, options: options)
        end
        success(line_item)
      end
    end
  end
end
