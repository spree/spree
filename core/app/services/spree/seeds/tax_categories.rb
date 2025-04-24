module Spree
  module Seeds
    class TaxCategories
      prepend Spree::ServiceModule::Base

      def call
        Spree::TaxCategory.find_or_create_by(name: 'Default', is_default: true)
        Spree::TaxCategory.find_or_create_by(name: 'Non-taxable')
      end
    end
  end
end
