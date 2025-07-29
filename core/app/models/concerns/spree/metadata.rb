module Spree
  module Metadata
    extend ActiveSupport::Concern

    included do
      # Legacy jsonb fields - to be deprecated
      attribute :public_metadata, default: {}
      attribute :private_metadata, default: {}

      serialize :public_metadata, coder: HashSerializer
      serialize :private_metadata, coder: HashSerializer

      # New metafields association
      has_many :metafield_definitions, -> { where(owner_type: self.class.name) }, as: :owner, class_name: 'Spree::MetafieldDefinition', dependent: :destroy
      has_many :metafields, as: :owner, class_name: 'Spree::Metafield', dependent: :destroy

      accepts_nested_attributes_for :metafields, allow_destroy: true, reject_if: lambda { |mf|
                                                                                    mf[:metafield_definition_id].blank? || (mf[:id].blank? && mf[:value].blank?)
                                                                                  }

      scope :with_metafield, ->(key) { joins(:metafield_definitions).where(spree_metafield_definitions: { key: key }) }
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
