module Spree
  module Admin
    class TaxCategoriesController < ResourceController
      add_breadcrumb Spree.t(:tax_categories), :admin_tax_categories_path
    end
  end
end
