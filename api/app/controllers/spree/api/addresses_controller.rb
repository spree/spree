module Spree
  module Api
    class AddressesController < Spree::Api::BaseController
      respond_to :json

      def show
        @address = Address.find(params[:id])
        authorize! :read, @address
        respond_with(@address)
      end

      def update
        @address = Address.find(params[:id])
        authorize! :read, @address
        @address.update_attributes(params[:address])
        respond_with(@address, :default_template => :show)
      end
    end
  end
end
