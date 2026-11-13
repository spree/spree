require 'rails/engine'

module SpreeKlaviyo
  class Engine < Rails::Engine
    engine_name 'spree_klaviyo'

    config.after_initialize do
      Spree.integrations << 'Spree::Integrations::Klaviyo'

      Spree.subscribers.push(
        SpreeKlaviyo::CustomerSubscriber,
        SpreeKlaviyo::NewsletterSubscriber,
        SpreeKlaviyo::OrderSubscriber,
        SpreeKlaviyo::FulfillmentSubscriber,
        SpreeKlaviyo::ReturnSubscriber
      )

      Spree.hooks.register('customers.anonymize.after_anonymize', 'SpreeKlaviyo::RequestProfileDeletion')
    end
  end
end
