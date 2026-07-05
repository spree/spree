module Spree
  module Admin
    module ProductsBreadcrumbConcern
      extend ActiveSupport::Concern

      included do
        add_breadcrumb_icon 'box'
        add_breadcrumb Spree.t(:products), :admin_products_path

        before_action :add_breadcrumb_for_product, only: [:edit, :update]
      end

      private

      def add_breadcrumb_for_product
        return unless @product.present?
        return if @product.new_record?
        add_breadcrumb @product.name, spree.edit_admin_product_path(@product)
      end
    end
  end
end
