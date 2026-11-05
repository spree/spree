FactoryBot.define do
  factory :klaviyo_integration, class: 'Spree::Integrations::Klaviyo' do
    store { Spree::Store.default }
    active { false }
    preferred_klaviyo_private_api_key { 'pk_test_key' }
    preferred_default_newsletter_list_id { 'LIST01' }

    # Activation calls Klaviyo, so an active integration is saved as inactive
    # and switched on without the connection check.
    trait :active do
      after(:create) { |integration| integration.update_column(:active, true) }
    end
  end
end
