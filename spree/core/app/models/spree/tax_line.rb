module Spree
  # A single tax charge on a line item, fulfillment or fee. Written exclusively
  # by the tax provider (see Spree::Purchase::Taxation#tax_provider) with replace-all set semantics
  # per estimate. Snapshot columns (+rate+, +label+, +provider_id+) keep rows
  # self-describing after a TaxRate is deleted or when an external provider
  # computed them.
  class TaxLine < Spree.base_class
    include Spree::TypedAdjustmentLine

    has_prefix_id :tl

    # Why this line was taxed the way it was — the machine-readable cause, kept
    # free of any one jurisdiction's invoice vocabulary so reporting and
    # e-invoicing can map it to whatever codes their regime requires.
    #
    # Configuration, not a frozen constant — a provider modelling a treatment
    # core doesn't know about registers its reason here. The bar for a new
    # value: it distinguishes a treatment that reporting or invoicing has to
    # tell apart, not merely a different amount.
    class_attribute :taxability_reasons,
                    default: %w[standard_rated reduced_rated zero_rated reverse_charge
                                intra_community_supply export customer_exempt product_exempt
                                not_collecting not_subject_to_tax]

    # Provider payloads (jurisdiction breakdowns, external ids) read nil-safe.
    attribute :data, default: -> { {} }

    # The jurisdiction snapshot the provider stamped on the line.
    has_iso_geography

    # Source — nil for externally-computed tax
    belongs_to :tax_rate, class_name: 'Spree::TaxRate', optional: true

    # Adjustable — exactly one
    belongs_to :line_item, class_name: 'Spree::LineItem', optional: true
    belongs_to :fulfillment, class_name: 'Spree::Fulfillment', optional: true
    belongs_to :fee, class_name: 'Spree::Fee', optional: true

    # Tax included in price vs additional. Per-row (mixed regimes on one order).
    attribute :included, :boolean, default: false

    validates :rate, numericality: { greater_than_or_equal_to: 0 }
    # The lambda re-reads the list at validation time, so a reason an extension
    # registers after boot is accepted.
    validates :taxability_reason,
              inclusion: { in: ->(tax_line) { tax_line.class.taxability_reasons } },
              allow_nil: true
    validate :exactly_one_adjustable

    # Tax reporting is the reason the treatment columns exist — "which country's
    # tax was this, and which sales were reverse-charged" has to be answerable.
    self.whitelisted_ransackable_attributes = %w[taxability_reason country_iso state_code included provider_id]

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
