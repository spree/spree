module Spree
  # What a provider shows on its gallery card in the dashboard: a logo and a
  # link to its setup guide. Shared by integrations and payment methods so a
  # provider gem declares both the same way whichever family it extends.
  #
  #   class SpreeStripe::Gateway < Spree::Gateway
  #     def self.logo_url = 'https://example.com/stripe.png'
  #     def self.docs_url = 'https://spreecommerce.org/docs/integrations/payments/stripe'
  #   end
  module ProviderListing
    extend ActiveSupport::Concern

    class_methods do
      # Logo shown on the gallery card: an absolute URL to publicly hosted
      # brand assets, or a `data:` URI for gems that want to be self-contained
      # (works air-gapped, no CSP domain to allowlist). Anything an `<img src>`
      # accepts. Deliberately not an asset-pipeline path — provider gems must
      # not force an asset pipeline onto headless API hosts. Hosted logos are a
      # courtesy, not a guarantee: the dashboard falls back to a letter avatar
      # when unset or unreachable.
      #
      # @return [String, nil]
      def logo_url
        nil
      end

      # Absolute URL of the provider's setup guide, linked from its gallery
      # card. A third-party gem points at its own documentation.
      #
      # @return [String, nil]
      def docs_url
        nil
      end

      # @return [Hash] the listing attributes merged into a type-discovery entry
      def provider_listing
        { logo_url: logo_url, docs_url: docs_url }
      end
    end
  end
end
