module Spree
  module Seeds
    # The reasons a business can give for buying without tax. Neutral codes
    # that Spree's own engine keeps for reference; a store using an engine
    # that reads them (Avalara) changes each code to that engine's.
    class TaxExemptionReasons
      prepend Spree::ServiceModule::Base
      include StoreScoped

      REASONS = {
        'RESALE' => 'Resale',
        'GOVERNMENT' => 'Government',
        'CHARITABLE' => 'Charitable organization',
        'EDUCATIONAL' => 'Educational institution',
        'MANUFACTURING' => 'Manufacturing',
        'AGRICULTURAL' => 'Agricultural'
      }.freeze

      private

      def seed(store)
        REASONS.each do |code, name|
          store.tax_exemption_reasons.find_or_create_by_code_or_name!(code: code, name: name)
        end
      end
    end
  end
end
