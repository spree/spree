module Spree
  module Metadata
    extend ActiveSupport::Concern

    include Spree::Metafields unless included_modules.include?(Spree::Metafields)

    included do
      attribute :public_metadata, default: {}
      attribute :private_metadata, default: {}

      serialize :public_metadata, coder: HashSerializer
      serialize :private_metadata, coder: HashSerializer
    end

    # `metadata` is the primary API-facing accessor.
    # It maps to `private_metadata` under the hood (Stripe-style: write-only, never returned in Store API).
    def metadata
      private_metadata
    end

    def metadata=(value)
      self.private_metadata = value
    end

    # https://nandovieira.com/using-postgresql-and-jsonb-with-ruby-on-rails
    class HashSerializer
      def self.dump(hash)
        hash
      end

      def self.load(hash)
        (hash || {}).with_indifferent_access
      end
    end
  end
end
