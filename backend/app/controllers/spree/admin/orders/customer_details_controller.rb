module Spree
  module Admin
    module Orders
      class CustomerDetailsController < Spree::Admin::BaseController
        before_filter :load_order

        def show
          edit
          render :action => :edit
        end

        def edit
          country_id = Address.default.country.id
          @order.build_bill_address(:country_id => country_id) if @order.bill_address.nil?
          @order.build_ship_address(:country_id => country_id) if @order.ship_address.nil?
        end

        def update
          if @order.update_attributes(params[:order])
            while @order.next; end

            @order.shipments.map &:refresh_rates
            flash[:success] = Spree.t('customer_details_updated')
            redirect_to admin_order_customer_path(@order)
          else
            render :action => :edit
          end

        end

        private

          def load_order
            @order = Order.find_by_number!(params[:order_id], :include => :adjustments)
          end

      end
    end
  end
end
