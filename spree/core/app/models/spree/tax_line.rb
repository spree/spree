module Spree
  # A single tax charge on a line item, fulfillment or fee. Written exclusively
  # by the tax provider (see Spree.tax_provider) with replace-all set semantics
  # per estimate. Snapshot columns (+rate+, +label+, +provider_id+) keep rows
  # self-describing after a TaxRate is deleted or when an external provider
  # computed them.
  class TaxLine < Spree.base_class
    include Spree::TypedAdjustmentLine

    has_prefix_id :tl

    # Source — nil for externally-computed tax
    belongs_to :tax_rate, class_name: 'Spree::TaxRate', optional: true

    # Adjustable — exactly one
    belongs_to :line_item, class_name: 'Spree::LineItem', optional: true
    belongs_to :fulfillment, class_name: 'Spree::Fulfillment', optional: true
    belongs_to :fee, class_name: 'Spree::Fee', optional: true

    # Tax included in price vs additional. Per-row (mixed regimes on one order).
    attribute :included, :boolean, default: false

    validates :rate, numericality: { greater_than_or_equal_to: 0 }
    validate :exactly_one_adjustable

    scope :included_in_price, -> { where(included: true) }
    scope :additional, -> { where(included: false) }
    scope :for_line_items, -> { where.not(line_item_id: nil) }
    scope :for_fulfillments, -> { where.not(fulfillment_id: nil) }
    scope :for_fees, -> { where.not(fee_id: nil) }

    # @return [Spree::LineItem, Spree::Fulfillment, Spree::Fee, nil]
    def adjustable
      line_item || fulfillment || fee
    end

    def included?
      included
    end

    def additional?
      !included
    end

    private

    def exactly_one_adjustable
      errors.add(:base, Spree.t('errors.messages.exactly_one_adjustable')) unless [line_item, fulfillment, fee].compact.one?
    end
  end
end
