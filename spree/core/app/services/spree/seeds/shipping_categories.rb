module Spree
  module Seeds
    class ShippingCategories
      prepend Spree::ServiceModule::Base

      def call
        Spree::ShippingCategory.find_or_create_by!(name: I18n.t('spree.seed.shipping.categories.default'))
        Spree::ShippingCategory.find_or_create_by!(name: I18n.t('spree.seed.shipping.categories.digital'))
      end
    end
  end
end
