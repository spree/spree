module Spree
  module Seeds
    class StoreCreditCategories
      prepend Spree::ServiceModule::Base

      def call
        # FIXME: we should use translations here
        Spree::StoreCreditCategory.find_or_create_by!(name: 'Default')
        Spree::StoreCreditCategory.find_or_create_by!(name: 'Non-expiring')
        Spree::StoreCreditCategory.find_or_create_by!(name: 'Expiring')
      end
    end
  end
end
