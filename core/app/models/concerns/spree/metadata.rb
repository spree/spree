module Spree
  module Metadata
    extend ActiveSupport::Concern

    included do
      attribute :public_metadata, default: {} if Rails.version.to_f >= 6.1
      attribute :private_metadata, default: {} if Rails.version.to_f >= 6.1
      serialize :public_metadata, HashSerializer
      serialize :private_metadata, HashSerializer
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
