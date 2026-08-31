module Spree
  # A catalog's purchasing rules for one variant — the narrowest of the three
  # levels a buyer's rules resolve through (variant base -> the catalog's own
  # default columns -> this row).
  #
  # Both fields are independently optional: a row stating only a minimum
  # leaves the multiple to the level below, because agreements are read
  # per-field and one that is silent on a field passes it through rather than
  # waiving it.
  class CatalogQuantityRule < Spree.base_class
    has_prefix_id :cqr

    belongs_to :catalog, class_name: 'Spree::Catalog', touch: true, inverse_of: :quantity_rules
    belongs_to :variant, class_name: 'Spree::Variant'

    validates :variant_id, uniqueness: { scope: [:catalog_id, *spree_base_uniqueness_scope] }
    validates :minimum_order_quantity, numericality: { only_integer: true, greater_than: 0, allow_nil: true }
    validates :order_multiple, numericality: { only_integer: true, greater_than: 0, allow_nil: true }
    validate :states_something
    validate :variant_in_same_store

    delegate :store, :store_id, to: :catalog

    # A catalog's terms are invalidated the moment they change: the resolved
    # set is memoized per request, and a rule edited in the same request must
    # not be read back stale.
    after_commit -> { Spree::Current.applicable_catalogs = nil }

    # @return [Spree::QuantityRule] this row's contribution, unresolved
    def to_quantity_rule
      Spree::QuantityRule.new(
        minimum_order_quantity: minimum_order_quantity,
        order_multiple: order_multiple
      )
    end

    private

    # A row stating neither field says nothing at all, which reads as an
    # override that overrides nothing — almost certainly a half-filled form.
    def states_something
      return if minimum_order_quantity.present? || order_multiple.present?

      errors.add(:base, :quantity_rule_states_nothing)
    end

    def variant_in_same_store
      return if variant.nil? || catalog.nil?
      return if variant.product&.store_id == catalog.store_id

      errors.add(:variant, :invalid)
    end
  end
end
