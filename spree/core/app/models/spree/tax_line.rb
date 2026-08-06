module Spree
  # A single tax charge on a line item, fulfillment or fee. Written exclusively
  # by the tax provider (see Spree.tax_provider) with replace-all set semantics
  # per estimate. Snapshot columns (+rate+, +label+, +provider_id+) keep rows
  # self-describing after a TaxRate is deleted or when an external provider
  # computed them.
  class TaxLine < Spree.base_class
    include Spree::TypedAdjustmentLine

    has_prefix_id :tl

    # Why this line was taxed the way it was. Configuration, not a frozen
    # constant — a provider modelling a treatment core doesn't know about
    # registers its reason here, together with an INVOICE_CATEGORY_CODES entry.
    # The bar for a new value: it maps to a distinct invoice category code, or
    # to a distinct box on a tax return.
    class_attribute :taxability_reasons,
                    default: %w[standard_rated reduced_rated zero_rated reverse_charge
                                intra_community_supply export customer_exempt product_exempt
                                not_collecting not_subject_to_tax]

    # Reason -> EN 16931 invoice category code (BT-151), from the UNTDID 5305
    # list. Shipped as code so a revision rides a release rather than a data
    # migration. Not exhaustive of the code list: `not_collecting` has no
    # meaningful code, since there is no EU VAT invoice to produce.
    INVOICE_CATEGORY_CODES = {
      'standard_rated' => 'S',
      'reduced_rated' => 'S',
      'zero_rated' => 'Z',
      'reverse_charge' => 'AE',
      'intra_community_supply' => 'K',
      'export' => 'G',
      'customer_exempt' => 'E',
      'product_exempt' => 'E',
      'not_subject_to_tax' => 'O'
    }.freeze

    # Reason -> EN 16931 exemption reason code (BT-121) for the cross-border
    # cases. Genuinely exempt supplies (healthcare, education, financial
    # services) are absent by design: their code depends on which exemption
    # applied, which lives with the exemption input and the tax category.
    EXEMPTION_REASON_CODES = {
      'reverse_charge' => 'VATEX-EU-AE',
      'intra_community_supply' => 'VATEX-EU-IC',
      'export' => 'VATEX-EU-G',
      'not_subject_to_tax' => 'VATEX-EU-O'
    }.freeze

    # Provider payloads (jurisdiction breakdowns, external ids) read nil-safe.
    attribute :data, default: -> { {} }

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

    scope :included_in_price, -> { where(included: true) }
    scope :additional, -> { where(included: false) }
    scope :for_line_items, -> { where.not(line_item_id: nil) }
    scope :for_fulfillments, -> { where.not(fulfillment_id: nil) }
    scope :for_fees, -> { where.not(fee_id: nil) }

    # @return [Spree::LineItem, Spree::Fulfillment, Spree::Fee, nil]
    def adjustable
      line_item || fulfillment || fee
    end

    # The EN 16931 invoice category code (BT-151) an e-invoice line carries.
    #
    # @return [String, nil] nil when the reason is unset or maps to no code
    def category_code
      INVOICE_CATEGORY_CODES[taxability_reason]
    end

    # The EN 16931 exemption reason code (BT-121). Nil for a genuinely exempt
    # supply, whose code depends on which exemption applied rather than on the
    # reason alone.
    #
    # @return [String, nil]
    def exemption_reason_code
      EXEMPTION_REASON_CODES[taxability_reason]
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
