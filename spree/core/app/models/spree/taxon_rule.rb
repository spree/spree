module Spree
  class TaxonRule < Spree.base_class
    has_prefix_id :txrule

    MATCH_POLICIES = %w[
      is_equal_to
      is_not_equal_to
      contains
      does_not_contain
    ].freeze

    # Category no longer declares the has_many :taxon_rules inverse (categories are
    # manual in 6.0), so this is a plain belongs_to. Data-only until 6.1.
    belongs_to :taxon, class_name: 'Spree::Category', touch: true

    validates :taxon, :type, :value, presence: true
    validates :match_policy, inclusion: { in: MATCH_POLICIES }, presence: true

    delegate :store, to: :taxon

    # Retained as a data-only model in 6.0 so the taxons -> collections data
    # migration can read existing automatic-taxon rules; dropped in 6.1 along
    # with the spree_taxon_rules table. Automatic membership now lives on
    # Spree::Collection (rule matching + regeneration moved there).
  end
end
