module Spree
  # What a purchase order and a stock transfer have in common: lines that
  # promise a quantity, deliveries that bring some of it, and a status that
  # says how far along that is.
  module Receivable
    extend ActiveSupport::Concern

    OPEN_STATUSES = %w[draft ready_to_ship ordered in_transit partially_received].freeze
    CLOSED_STATUSES = %w[received over_received canceled].freeze
    # The statuses in which a document's awaited units are on their way — and
    # so count toward the destination's `incoming_count`. A draft or a packed
    # box is not moving yet.
    INCOMING_STATUSES = %w[ordered in_transit partially_received].freeze

    included do
      has_many :stock_receipts, as: :receivable, class_name: 'Spree::StockReceipt',
                                inverse_of: :receivable, dependent: :destroy

      scope :open, -> { where(status: OPEN_STATUSES & statuses) }
      scope :closed, -> { where(status: CLOSED_STATUSES & statuses) }
      scope :incoming, -> { where(status: INCOMING_STATUSES & statuses) }

      validate :items_name_distinct_variants
    end

    def items_count
      items.size
    end

    def quantity_expected_total
      items.sum(&:quantity_expected)
    end

    def quantity_received_total
      items.sum { |item| item.quantity_received.to_i }
    end

    def quantity_rejected_total
      items.sum { |item| item.quantity_rejected.to_i }
    end

    # Whether any line is still owed units.
    #
    # @return [Boolean]
    def short?
      items.any?(&:under_received?)
    end

    # Whether any line took in more than it expected.
    #
    # @return [Boolean]
    def over?
      items.any?(&:over_received?)
    end

    def fully_received?
      items.any? && !short?
    end

    # Where a delivery leaves the document: over-receipt outranks a shortfall
    # elsewhere, because the extra units are already on the shelf and nothing
    # further can be expected once the supplier has sent more than was asked.
    #
    # @return [String]
    def status_after_receive
      return 'over_received' if over?

      fully_received? ? 'received' : 'partially_received'
    end

    def open?
      OPEN_STATUSES.include?(status)
    end

    # Whether the units still awaited are on their way, and so counted as
    # incoming at the destination.
    #
    # @return [Boolean]
    def incoming?
      INCOMING_STATUSES.include?(status)
    end

    def closed?
      CLOSED_STATUSES.include?(status)
    end

    # Closed by the merchant with units still owed, rather than by a delivery.
    #
    # @return [Boolean]
    def closed_short?
      closed_short_at.present?
    end

    private

    def items_name_distinct_variants
      variant_ids = items.reject(&:marked_for_destruction?).filter_map(&:variant_id)
      return if variant_ids.uniq.size == variant_ids.size

      errors.add(:items, :duplicate_variant, message: Spree.t('errors.messages.duplicate_variant'))
    end
  end
end
