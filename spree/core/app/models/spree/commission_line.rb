# frozen_string_literal: true

module Spree
  # What one sale earned the marketplace, frozen at placement.
  #
  # Deliberately **not** a Spree::Fee. A fee is buyer-facing and rolls into the
  # order total; a commission is a platform↔seller settlement the customer
  # never sees, so it lives off the order and never touches its totals. It
  # merely follows the same typed-line design — concrete FKs, no polymorphic
  # source, no state machine.
  #
  # Every field is a snapshot: the rate that applied, what it charged, and the
  # VAT charged on top of it. Editing the Spree::CommissionRate afterwards
  # changes nothing here, and neither does deleting it.
  #
  # `tax_amount` is the EU piece and the reason this model exists rather than a
  # single `amount` column: the marketplace's commission is its own taxable B2B
  # supply to the seller, separate from the consumer's item sale, so the two
  # VATs are computed independently and never mix.
  class CommissionLine < Spree.base_class
    has_prefix_id :cline

    include Spree::Metadata

    # Where the fee was taxed, validated against the ISO registry like every
    # other geography column. The seller's own jurisdiction, not the shopper's.
    has_iso_geography

    #
    # Associations
    #
    belongs_to :order, class_name: 'Spree::Order'
    belongs_to :seller, class_name: 'Spree::Seller'
    # Exactly one of these: the item that was commissioned, or the delivery,
    # when the rate carries include_shipping.
    belongs_to :line_item, class_name: 'Spree::LineItem', optional: true
    belongs_to :fulfillment, class_name: 'Spree::Fulfillment', optional: true
    # Optional because configuration outlives its use the other way round: the
    # rate may be deleted while this record has to stay readable.
    belongs_to :commission_rate, class_name: 'Spree::CommissionRate', optional: true

    #
    # Validations
    #
    validates :amount, :tax_amount, :total, :rate, :tax_rate, numericality: true
    # Deliberately Spree::TaxLine's vocabulary rather than a second one: an
    # invoice explaining why a marketplace fee was zero-rated or reverse-charged
    # should use the same words as the one explaining it for goods, and a
    # provider registering a new treatment registers it once. Read through the
    # lambda so a reason added after boot is accepted, as it is there.
    validates :taxability_reason,
              inclusion: { in: ->(_line) { Spree::TaxLine.taxability_reasons } },
              allow_nil: true
    validates :currency, presence: true
    validates :kind, presence: true, inclusion: { in: Spree::CommissionRate::KINDS }
    validate :exactly_one_subject

    #
    # Scopes
    #
    scope :for_line_items, -> { where.not(line_item_id: nil) }
    scope :for_fulfillments, -> { where.not(fulfillment_id: nil) }

    self.whitelisted_ransackable_attributes = %w[amount tax_amount total currency kind rate]
    self.whitelisted_ransackable_associations = %w[order seller commission_rate]

    extend Spree::DisplayMoney
    money_methods :amount, :tax_amount, :total

    # What this row was charged against.
    #
    # @return [Spree::LineItem, Spree::Fulfillment, nil]
    def subject
      line_item || fulfillment
    end

    private

    def exactly_one_subject
      return if [line_item_id, fulfillment_id].compact.one?

      errors.add(:base, :exactly_one_of_line_item_or_fulfillment, message: Spree.t('errors.messages.exactly_one_of_line_item_or_fulfillment'))
    end
  end
end
