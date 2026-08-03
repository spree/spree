module Spree
  module Seeds
    class ProductTypes
      prepend Spree::ServiceModule::Base

      def call
        Spree::Store.all.find_each do |store|
          Spree::ProductType.where(store: store).find_or_create_by!(name: I18n.t('spree.seed.product_types.default')) do |product_type|
            product_type.fulfillment_types = ['shipping']
          end
          Spree::ProductType.where(store: store).find_or_create_by!(name: I18n.t('spree.seed.product_types.digital')) do |product_type|
            product_type.fulfillment_types = ['digital']
          end
        end
      end
    end
  end
end
