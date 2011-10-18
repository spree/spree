module Spree
  module Admin
    # Need to explicitly reference namespaced ResourceController here
    # Due to the rd_resource_controller gem, which provides a top-level
    # ResourceController module, which is obviously not inheritable from.
    class AdjustmentsController < Spree::Admin::ResourceController
      belongs_to 'spree/order', :find_by => :number
      destroy.after :reload_order

      private
        def reload_order
          @order.reload
        end
    end
  end
end
