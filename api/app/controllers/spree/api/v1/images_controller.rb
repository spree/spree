module Spree
  module Api
    module V1
      class ImagesController < Spree::Api::BaseController
        def index
          @images = scope.images.accessible_by(current_ability)
          respond_with(@images)
        end

        def show
          @image = Image.accessible_by(current_ability, :show).find(params[:id])
          respond_with(@image)
        end

        def new; end

        def create
          authorize! :create, Image
          @image = scope.images.new(image_params)
          if @image.save
            respond_with(@image, status: 201, default_template: :show)
          else
            invalid_resource!(@image)
          end
        end

        def update
          @image = scope.images.accessible_by(current_ability, :update).find(params[:id])
          if @image.update(image_params)
            respond_with(@image, default_template: :show)
          else
            invalid_resource!(@image)
          end
        end

        def destroy
          @image = scope.images.accessible_by(current_ability, :destroy).find(params[:id])
          @image.destroy
          respond_with(@image, status: 204)
        end

        private

        def image_params
          params.require(:image).permit(permitted_image_attributes)
        end

        def scope
          if params[:product_id]
            Spree::Product.friendly.find(params[:product_id])
          elsif params[:variant_id]
            Spree::Variant.find(params[:variant_id])
          end
        end
      end
    end
  end
end
