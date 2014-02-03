module Spree
  module Api
    class AddressesController < Spree::Api::BaseController
      before_filter :find_order

      def show
        if @order
          authorize! :read, @order, order_token
          find_address
        else
          find_address
        end
        respond_with(@address)
      end

      def update
        if @order
          authorize! :update, @order, order_token
          find_address
        else
          authorize! :update, @address
          find_address
        end

        if @address.update_attributes(address_params)
          respond_with(@address, :default_template => :show)
        else
          invalid_resource!(@address)
        end
      end

      private
        def address_params
          params.require(:address).permit(permitted_address_attributes)
        end

        def find_order
          @order = Spree::Order.find_by!(number: params[:order_id]) if params[:order_id]
        end

        def find_address
          if @order
            @address = if @order.bill_address_id == params[:id].to_i
              @order.bill_address
            elsif @order.ship_address_id == params[:id].to_i
              @order.ship_address
            else
              raise CanCan::AccessDenied
            end
          else
            @address = Spree::Address.find(params[:id])
          end
        end

        def order_token
          request.headers["X-Spree-Order-Token"] || params[:order_token]
        end
    end
  end
end