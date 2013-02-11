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
        authorize! :read, @address

        if @address.update_attributes(params[:address])
          respond_with(@address, :default_template => :show)
        else
          invalid_resource!(@address)
        end
      end
    end
  end
end
