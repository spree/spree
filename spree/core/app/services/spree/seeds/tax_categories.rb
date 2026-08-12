module Spree
  module Seeds
    class TaxCategories
      prepend Spree::ServiceModule::Base

      def call
        Spree::Store.find_each do |store|
          # The block form only runs on create, so a store that already had a
          # "Default" category with the flag unset kept no default at all — and
          # the default is what taxes an item carrying no category of its own.
          default = store.tax_categories.find_or_create_by!(name: 'Default')
          default.update!(is_default: true) unless default.is_default?

          store.tax_categories.find_or_create_by!(name: 'Non-taxable')
        end
      end
    end
  end
end
