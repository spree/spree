module Spree
  module Emails
    class StoreSerializer < BaseSerializer
      include Spree::ImagesHelper

      LOGO_HEIGHT = 32

      attributes :name, :address, :mail_from_address, :default_currency, :default_locale

      attribute :url, &:storefront_url

      attribute :support_email do |store|
        store.customer_support_email.presence || store.mail_from_address
      end

      attribute :logo_url do |store|
        spree_image_url(store.email_logo, height: LOGO_HEIGHT)
      end

      # The width the logo shows at, from its proportions. Analyzing an
      # unanalyzed logo here keeps a wide logo from being squashed square.
      attribute :logo_width do |store|
        logo = store.email_logo
        next unless logo

        logo.analyze unless logo.analyzed?
        width, height = logo.metadata.values_at('width', 'height').map(&:to_f)
        height.positive? ? (LOGO_HEIGHT * width / height).round : nil
      end

      attribute :logo_height do |store|
        LOGO_HEIGHT if store.email_logo
      end
    end
  end
end
