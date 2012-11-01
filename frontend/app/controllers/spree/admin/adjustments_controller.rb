module Spree
  module Admin
    class AdjustmentsController < ResourceController
      belongs_to 'spree/order', :find_by => :number
      destroy.after :reload_order

      private
        def reload_order
          @order.reload
        end
    end
  end
end
