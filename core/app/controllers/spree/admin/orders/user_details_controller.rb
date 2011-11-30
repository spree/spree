module Spree
  module Admin
    module Orders
      class UserDetailsController < Spree::Admin::BaseController
        before_filter :load_order

        def show
          puts "LOADING THE INDEX ACTION HERE"
          @order.build_bill_address(:country_id => Spree::Config[:default_country_id]) if @order.bill_address.nil?
          @order.build_ship_address(:country_id => Spree::Config[:default_country_id]) if @order.ship_address.nil?
        end

        private

        def load_order
          @order = Order.find_by_number(params[:order_id], :include => :adjustments)
        end

      end
    end
  end
end
