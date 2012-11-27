module Spree
  module Api
    class ImagesController < Spree::Api::BaseController
      def show
        @image = Image.find(params[:id])
      end

      def create
        authorize! :create, Image
        @image = Image.create(params[:image])
        render :show, :status => 201
      end

      def update
        authorize! :update, Image
        @image = Image.find(params[:id])
        @image.update_attributes(params[:image])
        render :show, :status => 200
      end

      def destroy
        authorize! :delete, Image
        @image = Image.find(params[:id])
        @image.destroy
        render :text => nil, :status => 204
      end
    end
  end
end
