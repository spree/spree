module Spree
  module Seeds
    class ShippingCategories
      prepend Spree::ServiceModule::Base

      def call
        # FIXME: we should use translations here
        Spree::ShippingCategory.find_or_create_by!(name: 'Default')
      end
    end
  end
end
