module Spree
  module Admin
    class ShippingCategoriesController < ResourceController
      add_breadcrumb Spree.t(:shipping_categories), :admin_shipping_categories_path
    end
  end
end
