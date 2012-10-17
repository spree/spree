module Spree
  module Api
    module V1
      class AddressesController < Spree::Api::V1::BaseController
        def show
          @address = Address.find(params[:id])
          authorize! :read, @address
        end

        def update
          @address = Address.find(params[:id])
          authorize! :read, @address
          @address.update_attributes(params[:address])
          render :show, :status => 200
        end
      end
    end
  end
end
