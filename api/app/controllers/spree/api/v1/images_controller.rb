module Spree
  module Api
    module V1
      class ImagesController < Spree::Api::V1::BaseController
        def show
          @image = Image.find(params[:id])
        end

        def create
          @image = Image.create(params[:image])
          render :show, :status => 201
        end

        def update
          @image = Image.find(params[:id])
          @image.update_attributes(params[:image])
          render :show, :status => 200
        end

        def destroy
          @image = Image.find(params[:id])
          @image.destroy
          render :text => nil
        end

      end
    end
  end
end
