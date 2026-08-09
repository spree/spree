module Spree
  module Seeds
    class ProductTypes
      prepend Spree::ServiceModule::Base

      def call
        Spree::Store.all.find_each do |store|
          Spree::ProductType.where(store: store).find_or_create_by!(name: I18n.t('spree.seed.product_types.default'))
          Spree::ProductType.where(store: store).find_or_create_by!(name: I18n.t('spree.seed.product_types.digital')) do |product_type|
            product_type.delivery_profile = digital_profile_for(store)
          end
        end
      end

      private

      def digital_profile_for(store)
        Spree::DeliveryProfiles::Digital.find_by(store: store) ||
          Spree::DeliveryProfiles::Digital.create!(store: store, name: I18n.t('spree.seed.delivery_profiles.digital'))
      end
    end
  end
end
