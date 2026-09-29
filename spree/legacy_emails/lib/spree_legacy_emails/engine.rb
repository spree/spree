require 'rails/engine'

module SpreeLegacyEmails
  # Installing this gem switches Spree's email lookup back on for ERB views,
  # so the pre-6.0 emails and a host app's ERB overrides keep rendering.
  # Deprecated; removed in Spree 6.1.
  class Engine < Rails::Engine
    engine_name 'spree_legacy_emails'

    config.to_prepare do
      Spree::BaseMailer.helper Spree::ImagesHelper, Spree::MailHelper, Spree::FulfillmentHelper, Spree::DigitalAssetHelper
    end
  end
end
