module Spree
  # A tax charge on a single line item or fulfillment, written by tax
  # calculation (interim: TaxRate.adjust; a TaxProvider in 6.x). Replaces
  # tax-sourced polymorphic adjustments with concrete, eager-loadable FKs.
  class TaxLine < Spree.base_class
    include Spree::AdjustmentLine

    has_prefix_id :tl

    belongs_to :order, class_name: 'Spree::Order', inverse_of: :tax_lines
    belongs_to :tax_rate, -> { with_deleted }, class_name: 'Spree::TaxRate'

    validates :amount, numericality: true

    # Tax can be included in the price (VAT-style) or additional (sales-tax-style)
    attribute :included, :boolean, default: false

    scope :included_in_price, -> { where(included: true) }
    scope :additional, -> { where(included: false) }
  end
end
