require 'rails/engine'

module SpreeVies
  class Engine < Rails::Engine
    engine_name 'spree_vies'

    config.after_initialize do
      # Core registers a format-only validator for EU VAT numbers. This one keeps
      # that check and adds the registry lookup, so installing the gem is what
      # turns verification on — unless the application registered a validator of
      # its own, which stays.
      if Spree.tax_identifier_validators['eu_vat'] == 'Spree::TaxIdentifiers::Validator::EuVat'
        Spree.tax_identifier_validators['eu_vat'] = 'SpreeVies::Validator'
      end
    end
  end
end
