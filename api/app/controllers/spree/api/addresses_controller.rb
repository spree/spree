module Spree
  module Api
    class AddressesController < Spree::Api::BaseController
      before_filter :find_order

      def show
        load_and_authorize_address(:read)
        respond_with(@address)
      end

      def update
        load_and_authorize_address(:update)

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
          @order = Spree::Order.find_by!(number: order_id) if order_id
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

        def load_and_authorize_address(permission)
          find_address
          if @order
            authorize! permission, @order, order_token
          else
            authorize! permission, @address
          end
        end
    end
  end
end
