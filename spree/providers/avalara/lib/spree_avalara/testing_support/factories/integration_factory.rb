FactoryBot.define do
  factory :avalara_integration, class: 'SpreeAvalara::Integration' do
    store { Spree::Store.default || create(:store) }
    # Inactive by default: activating verifies the connection, and an example
    # that only needs credentials on file should not reach for the network.
    active { false }

    preferred_account_number { ENV.fetch('AVATAX_ACCOUNT_NUMBER', '2000000000') }
    preferred_license_key { ENV.fetch('AVATAX_LICENSE_KEY', 'test_license_key') }
    # Not ENV-driven like the credentials: the model now allows only Avalara's
    # two published hosts, so an override could only ever build an invalid
    # record. Cassettes are recorded against the sandbox.
    preferred_endpoint { SpreeAvalara::Integration::SANDBOX_ENDPOINT }
    preferred_company_code { ENV.fetch('AVATAX_COMPANY_CODE', 'DEFAULT') }
    preferred_commit_transaction_enabled { true }
    preferred_address_validation_enabled { false }
    preferred_show_rate_in_label { false }

    # An integration a store can actually calculate through, without a cassette
    # or a stub in every example that wants one.
    trait :active do
      active { true }

      after(:build) do |integration|
        integration.define_singleton_method(:can_connect?) { true }
      end
    end
  end
end
