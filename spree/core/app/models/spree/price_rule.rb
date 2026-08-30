module Spree
  class PriceRule < Spree.base_class
    has_prefix_id :prule

    belongs_to :price_list, class_name: 'Spree::PriceList', touch: true

    delegate :store, to: :price_list

    validates :type, presence: true
    validates :type, uniqueness: { scope: [:price_list_id, *spree_base_uniqueness_scope] }

    # Returns true if the price rule is applicable to the context
    # @param context [Spree::Pricing::Context]
    # @return [Boolean]
    def applicable?(context)
      raise NotImplementedError, "#{self.class.name} must implement #applicable?"
    end

    # Whether this rule narrows its price list by geography. A list carrying one
    # states the price for that geography outright, so its prices are charged as
    # entered and never restated for the buyer's VAT rate
    # (Spree::VatPriceCalculation). A rule that narrows by anything else — a
    # quantity, a group, a channel — leaves its prices open to restatement, since
    # they were not set for a country.
    #
    # @return [Boolean]
    def geographic?
      false
    end

    # Whether a better mechanism has replaced this rule kind. Superseded
    # kinds are grandfathered — existing rules keep matching indefinitely —
    # but they are flagged in types discovery so pickers stop offering them
    # to new setups (docs/plans/6.0-catalog-agreement-rework.md).
    #
    # @return [Boolean]
    def self.superseded?
      false
    end

    # Returns the human name of the price rule
    # @return [String]
    def self.human_name
      name.demodulize.titleize
    end

    # Returns the description of the price rule
    # @return [String]
    def self.description
      ''
    end

    registers_subclasses_via { Array(Spree.pricing&.rules) }
  end
end
