module Spree
  module LineItems
    class Update
      prepend Spree::ServiceModule::Base
      include Helper

      def call(line_item:, line_item_attributes: {}, options: {})
        ActiveRecord::Base.transaction do
          return failure(line_item) unless line_item.update(line_item_attributes)

          recalculate_service.call(order: line_item.order, line_item: line_item, options: options)
        end
        success(line_item)
      end
    end
  end
end
