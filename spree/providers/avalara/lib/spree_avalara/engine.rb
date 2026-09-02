require 'rails/engine'

module SpreeAvalara
  class Engine < Rails::Engine
    engine_name 'spree_avalara'

    config.generators do |g|
      g.test_framework :rspec
    end

    # Core assigns the registries in its own after_initialize, so appending has
    # to happen in a later one — engine callbacks run in load order.
    config.after_initialize do
      Spree.integrations << 'SpreeAvalara::Integration' unless Spree.integrations.include?('SpreeAvalara::Integration')
      Spree.tax_providers << SpreeAvalara::TaxProvider unless Spree.tax_providers.include?(SpreeAvalara::TaxProvider)
      Spree.hooks.register('carts.complete.validate', 'SpreeAvalara::CheckoutAddressValidation')

      # The exemption reasons AvaTax understands, offered to a merchant
      # recording a certificate. Merged rather than assigned, so another
      # provider's vocabulary survives.
      Spree.tax_exemption_reason_codes = Spree.tax_exemption_reason_codes.to_h.merge(
        SpreeAvalara::TaxProvider.display_name => SpreeAvalara::EntityUseCodes::ALL
      )
    end
  end
end
