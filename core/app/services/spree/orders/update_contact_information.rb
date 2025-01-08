module Spree
  module Orders
    class UpdateContactInformation
      prepend ::Spree::ServiceModule::Base

      def call(order:, order_params:)
        ActiveRecord::Base.transaction do
          order.update_columns(email: order_params[:email], updated_at: Time.current)

          if order.respond_to?(:vendor_orders) && order.vendor_orders.any?
            order.vendor_orders.update_all(email: order_params[:email], updated_at: Time.current)
          end
        end

        success(order.reload)
      end
    end
  end
end
