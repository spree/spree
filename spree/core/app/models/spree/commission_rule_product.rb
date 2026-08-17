# frozen_string_literal: true

module Spree
  # Join row between a Spree::CommissionRules::ProductRule and a product it
  # names. A concrete table because a marketplace's product list is
  # catalog-scale and does not belong in a preferences blob.
  class CommissionRuleProduct < Spree.base_class
    # No inverse_of: the association lives on the ProductRule subclass, not on
    # the base class this points at.
    # Retired with its rule, so a retired product rule still says which
    # products it named.
    acts_as_paranoid

    belongs_to :commission_rule, class_name: 'Spree::CommissionRule'
    belongs_to :product, class_name: 'Spree::Product'

    validates :product_id, uniqueness: { scope: [:commission_rule_id, *spree_base_uniqueness_scope] }
  end
end
