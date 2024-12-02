module Spree
  class TaxonRule < Spree.base_class
    MATCH_POLICIES = %w[
      is_equal_to
      is_not_equal_to
      contains
      does_not_contain
    ].freeze

    belongs_to :taxon, class_name: 'Spree::Taxon', inverse_of: :taxon_rules, touch: true

    validates :taxon, :type, :value, presence: true
    validates :match_policy, inclusion: { in: MATCH_POLICIES }, presence: true

    after_commit :regenerate_taxon_products, if: -> { saved_change_to_value? || destroyed? || saved_change_to_match_policy? }

    delegate :store, to: :taxon

    private

    def regenerate_taxon_products
      taxon.regenerate_taxon_products(only_once: true)
    end
  end
end
