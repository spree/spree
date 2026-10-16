module Spree
  module Seeds
    # The reasons a business can give for buying without tax. Neutral codes
    # that Spree's own engine keeps for reference; a store using an engine
    # that reads them (Avalara) adds its own reasons with that engine's codes.
    class TaxExemptionReasons
      prepend Spree::ServiceModule::Base
      include StoreScoped

      REASONS = {
        'resale' => 'Resale',
        'government' => 'Government',
        'charitable' => 'Charitable organization',
        'educational' => 'Educational institution',
        'manufacturing' => 'Manufacturing',
        'agricultural' => 'Agricultural'
      }.freeze

      private

      # Found by code, so a merchant who renamed a reason keeps their wording.
      def seed(store)
        REASONS.each do |code, name|
          store.tax_exemption_reasons.find_or_create_by!(code: code) { |reason| reason.name = name }
        end
      end
    end
  end
end
