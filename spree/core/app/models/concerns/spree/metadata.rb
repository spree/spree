module Spree
  module Metadata
    extend ActiveSupport::Concern

    include Spree::Metafields unless included_modules.include?(Spree::Metafields)

    included do
      attribute :metadata, default: {}

      serialize :metadata, coder: HashSerializer
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
