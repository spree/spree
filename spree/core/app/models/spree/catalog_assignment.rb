module Spree
  # Who gets a catalog. Polymorphic, but the assignable set is small and
  # closed: CustomerGroup and Company — buyer audiences only. A company-node
  # assignment applies to the node's subtree.
  #
  # Channel and Market were assignable in the 6.0 pre-release but never read
  # (decisions.md 2026-08-28): a channel's catalog is its `default_catalog`,
  # and a market catalog waits for the regional-assortment design. A future
  # type joins this list together with the resolution code that reads it.
  #
  # The assignment direction is "who gets this catalog", not "what catalogs
  # does this entity have" — resolution queries by catalog.
  class CatalogAssignment < Spree.base_class
    has_prefix_id :cata

    ASSIGNABLE_TYPES = %w[Spree::CustomerGroup Spree::Company].freeze

    belongs_to :catalog, class_name: 'Spree::Catalog', inverse_of: :catalog_assignments
    belongs_to :assignable, polymorphic: true

    validates :assignable_type, inclusion: { in: ASSIGNABLE_TYPES }
    validates :catalog_id, uniqueness: { scope: [:assignable_type, :assignable_id, *spree_base_uniqueness_scope] }
    validate :assignable_in_same_store

    after_commit -> { Spree::Current.applicable_catalogs = nil }

    delegate :store, :store_id, to: :catalog

    private

    # Every assignable type is store-scoped, so a cross-store assignment
    # would show one merchant's catalog to another's audience.
    def assignable_in_same_store
      return if assignable.nil? || catalog.nil?
      return unless assignable.respond_to?(:store_id)
      return if assignable.store_id == catalog.store_id

      errors.add(:assignable, :invalid)
    end
  end
end
