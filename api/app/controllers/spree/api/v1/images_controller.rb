module Spree
  module Api
    module V1
      class ImagesController < Spree::Api::V1::BaseController
        def create
          @image = product_or_variant.images.create!(params[:image])
          render :show, :status => 201
        end

        def update
          image.update_attributes(params[:image])
          render :show, :status => 200
        end

        def destroy
          image.destroy
          render :text => nil
        end

        private

        def image
          @image = product_or_variant.images.find(params[:id])
        end

        def product_or_variant
          return @product_or_variant if @product_or_variant
          if params[:product_id]
            @product_or_variant = product
          else
            @product_or_variant = variant
          end
        end

        def variant
          Variant.find(params[:variant_id])
        end

        def product
          begin
            find_product(params[:product_id])
          rescue ActiveRecord::RecordNotFound
            nil
          end
        end

      end
    end
  end
end
