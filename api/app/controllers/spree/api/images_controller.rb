module Spree
  module Api
    class ImagesController < Spree::Api::BaseController

      def show
        @image = Image.accessible_by(current_ability, :read).find(params[:id])
        respond_with(@image)
      end

      def create
        authorize! :create, Image
        @image = Image.create(params[:image])
        respond_with(@image, :status => 201, :default_template => :show)
      end

      def update
        @image = Image.accessible_by(current_ability, :update).find(params[:id])
        @image.update_attributes(params[:image])
        respond_with(@image, :default_template => :show)
      end

      def destroy
        @image = Image.accessible_by(current_ability, :destroy).find(params[:id])
        @image.destroy
        respond_with(@image, :status => 204)
      end
    end
  end
end
