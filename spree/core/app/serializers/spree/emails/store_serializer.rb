module Spree
  module Emails
    class StoreSerializer < BaseSerializer
      include Spree::ImagesHelper

      LOGO_HEIGHT = 32

      attributes :name, :address, :mail_from_address, :default_currency, :default_locale

      attribute :url, &:storefront_url

      attribute :support_email, &:support_email_address

      attribute :logo_url do |store|
        spree_image_url(store.email_logo, height: LOGO_HEIGHT)
      end

      # The width the logo shows at, from its proportions. Nil until the file
      # has been analyzed, when the layout lets the width follow the height.
      attribute :logo_width do |store|
        width, height = store.email_logo&.metadata.to_h.values_at('width', 'height').map(&:to_f)
        (LOGO_HEIGHT * width / height).round if height.to_f.positive?
      end
    end
  end
end
