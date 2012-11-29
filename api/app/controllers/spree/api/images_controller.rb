module Spree
  module Api
    class ImagesController < Spree::Api::BaseController
      respond_to :json

      def show
        @image = Image.find(params[:id])
        respond_with(@image)
      end

      def create
        authorize! :create, Image
        @image = Image.create(params[:image])
        respond_with(@image, :status => 201, :default_template => :show)
      end

      def update
        authorize! :update, Image
        @image = Image.find(params[:id])
        @image.update_attributes(params[:image])
        respond_with(@image, :default_template => :show)
      end

      def destroy
        authorize! :delete, Image
        @image = Image.find(params[:id])
        @image.destroy
        respond_with(@image, :status => 204)
      end
    end
  end
end
