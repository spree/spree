module Spree
  module Emails
    class StoreSerializer < BaseSerializer
      LOGO_HEIGHT = 32

      attributes :name, :address, :mail_from_address, :default_currency, :default_locale

      attribute :url, &:storefront_url

      attribute :support_email do |store|
        store.customer_support_email.presence || store.mail_from_address
      end

      attribute :logo_url do |store|
        logo = logo_for(store)
        next unless logo

        variant = logo.variant(format: 'webp', saver: Spree::Media::WEBP_SAVER_OPTIONS, resize_to_limit: [nil, LOGO_HEIGHT * 3])
        Rails.application.routes.url_helpers.cdn_image_url(variant)
      end

      attribute :logo_width do |store|
        logo = logo_for(store)
        next unless logo

        width = logo.metadata['width'].to_f
        height = logo.metadata['height'].to_f
        height.positive? ? (LOGO_HEIGHT * width / height).round : LOGO_HEIGHT
      end

      attribute :logo_height do |store|
        LOGO_HEIGHT if logo_for(store)
      end

      private

      def logo_for(store)
        logo = store.mailer_logo.attached? ? store.mailer_logo : store.logo
        logo if logo.attached? && logo.variable?
      end
    end
  end
end
