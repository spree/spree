module Spree
  module Api
    module V1
      class AddressesController < Spree::Api::V1::BaseController
        def show
          @address = Address.find(params[:id])
        end

        def update
          @address = Address.find(params[:id])
          @address.update_attributes(params[:address])
          render :show, :status => 200
        end
      end
    end
  end
end
