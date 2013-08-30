module Spree
  module Api
    class AddressesController < Spree::Api::BaseController
      before_filter :find_order

      def show
        authorize! :read, @order, params[:order_token]
        find_address
        respond_with(@address)
      end

      def update
        authorize! :update, @order, params[:order_token]
        find_address

        if @address.update_attributes(params[:address])
          respond_with(@address, :default_template => :show)
        else
          invalid_resource!(@address)
        end
      end

      private

        def find_order
          @order = Spree::Order.find_by_number!(params[:order_id])
        end

        def find_address
          @address = if @order.bill_address_id == params[:id].to_i
            @order.bill_address
          elsif @order.ship_address_id == params[:id].to_i
            @order.ship_address
          else
            raise CanCan::AccessDenied
          end
        end
    end
  end
end
