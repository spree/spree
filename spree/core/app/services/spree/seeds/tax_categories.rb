module Spree
  module Seeds
    class TaxCategories
      prepend Spree::ServiceModule::Base

      def call
        Spree::Store.find_each do |store|
          store.tax_categories.find_or_create_by!(name: 'Default') do |tax_category|
            tax_category.is_default = true
          end
          store.tax_categories.find_or_create_by!(name: 'Non-taxable')
        end
      end
    end
  end
end
