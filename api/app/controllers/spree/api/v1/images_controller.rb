module Spree
  module Api
    module V1
      class ImagesController < Spree::Api::V1::BaseController
        def create
          @image = product_or_variant.images.create!(params[:image])
          render :show, :status => 201
        end

        private

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
