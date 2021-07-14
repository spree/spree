module Spree
  module Admin
    class ImagesController < ResourceController
      include Spree::Admin::ProductConcern

      belongs_to 'spree/product', find_by: :slug

      before_action :load_edit_data, except: :index

      create.before :set_viewable
      update.before :set_viewable

      private

      def location_after_destroy
        spree.admin_product_images_url(@arent)
      end

      def location_after_save
        spree.admin_product_images_url(parent)
      end

      def load_edit_data
        @variants = parent.variants.map do |variant|
          [variant.sku_and_options_text, variant.id]
        end
        @variants.insert(0, [Spree.t(:all), parent.master.id])
      end

      def set_viewable
        @image.viewable_type = 'Spree::Variant'
        @image.viewable_id = params[:image][:viewable_id]
      end
    end
  end
end
