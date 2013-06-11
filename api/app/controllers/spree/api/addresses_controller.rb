module Spree
  module Api
    class AddressesController < Spree::Api::BaseController

      def show
        @address = Address.find(params[:id])
        authorize! :read, @address
        respond_with(@address)
      end

      def update
        @address = Address.find(params[:id])
        authorize! :update, @address

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
    end
  end
end
