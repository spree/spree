module Spree
  module Metadata
    extend ActiveSupport::Concern

    include Spree::HasCustomFields unless included_modules.include?(Spree::HasCustomFields)

    included do
      attribute :metadata, default: {}

      serialize :metadata, coder: HashSerializer
    end

    # Deprecated alias for the renamed `metadata` column. Removed in Spree 6.1.
    #
    # Only the reader and writer are bridged. The column is gone, so the attribute
    # methods Active Record generated alongside it — `private_metadata?`,
    # `private_metadata_changed?`, `private_metadata_was`,
    # `private_metadata_before_type_cast` and the rest of the dirty-tracking family
    # — no longer exist and raise NoMethodError. Call the `metadata` equivalents.
    def private_metadata
      Spree::Deprecation.warn('private_metadata is deprecated and will be removed in Spree 6.1. Use metadata instead.')
      metadata
    end

    def private_metadata=(value)
      Spree::Deprecation.warn('private_metadata= is deprecated and will be removed in Spree 6.1. Use metadata= instead.')
      self.metadata = value
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
