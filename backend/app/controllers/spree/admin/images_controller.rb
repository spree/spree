module Spree
  module Admin
    class ImagesController < ResourceController
      before_action :load_product
      before_action :load_edit_data, except: :index

      create.before :set_viewable
      update.before :set_viewable

      private

      def location_after_destroy
        spree.admin_product_images_url(@product)
      end

      def location_after_save
        spree.admin_product_images_url(@product)
      end

      def load_edit_data
        @variants = @product.variants.map do |variant|
          [variant.sku_and_options_text, variant.id]
        end
        @variants.insert(0, [Spree.t(:all), @product.master_id])
      end

      def set_viewable
        @image.viewable_type = 'Spree::Variant'
        @image.viewable_id = params[:image][:viewable_id]
      end

      def load_product
        @product = scope.friendly.find(params[:product_id])
      end

      def scope
        current_store.products
      end

      def collection_url
        spree.admin_product_images_url
      end

      def modle_class
        Spree::Image
      end

      def collection
        @collection ||= load_product.variant_images
      end
    end
  end
end
