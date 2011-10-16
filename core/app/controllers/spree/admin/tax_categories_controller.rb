module Spree
  module Admin
    class TaxCategoriesController < ResourceController
      def index
        if Spree::Config[:show_price_inc_vat] and (TaxCategory.where(:is_default => true).count != 1)
          flash.notice = t(:one_default_category_with_default_tax_rate)
        end
      end
    end
  end
end
