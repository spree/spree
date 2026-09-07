module Spree
  # A document whose line items expect goods to arrive at a stock location: a
  # stock transfer, a purchase order (docs/plans/6.0-inventory-operations.md).
  #
  # Owns the reads both share — the running totals a list page shows and the
  # question "did everything arrive?". The writes stay in the workflows, which
  # is what lets a receive carry the quantities the warehouse counted.
  #
  # Including classes provide an `items` association of {Spree::ReceivableItem}
  # rows and a `destination_location`.
  module Receivable
    extend ActiveSupport::Concern

    # The statuses a document sits in while goods are still expected.
    OPEN_STATUSES = %w[draft ready_to_ship ordered in_transit partially_received].freeze
    # The statuses nothing more will arrive in.
    CLOSED_STATUSES = %w[received canceled].freeze

    included do
      scope :open, -> { where(status: OPEN_STATUSES & statuses) }
      scope :closed, -> { where(status: CLOSED_STATUSES & statuses) }

      validate :items_name_distinct_variants
    end

    # @return [Integer]
    def items_count
      items.size
    end

    # How many units the document promises in total.
    #
    # @return [Integer]
    def quantity_expected_total
      items.sum(&:quantity_expected)
    end

    # How many units have been counted in so far.
    #
    # @return [Integer]
    def quantity_received_total
      items.sum { |item| item.quantity_received.to_i }
    end

    # Whether any line is still owed units — the opposite of
    # {#fully_received?} for a document that has lines at all.
    #
    # @return [Boolean]
    def under_received?
      items.any?(&:under_received?)
    end

    # Whether every line has arrived in full.
    #
    # @return [Boolean]
    def fully_received?
      items.any? && !under_received?
    end

    # The status a receive settles the document in: `received` once every line
    # is complete, `partially_received` while any is still owed.
    #
    # @return [String]
    def status_after_receive
      fully_received? ? 'received' : 'partially_received'
    end

    # Whether the document is still expecting goods.
    #
    # @return [Boolean]
    def open?
      OPEN_STATUSES.include?(status)
    end

    # @return [Boolean]
    def closed?
      CLOSED_STATUSES.include?(status)
    end

    private

    # Two lines for the same SKU make "how many are we sending?" ambiguous,
    # and would race the unique index besides. Checked here rather than as a
    # uniqueness validation on the line, which queries the database and so
    # cannot see its own unsaved siblings.
    def items_name_distinct_variants
      variant_ids = items.reject(&:marked_for_destruction?).filter_map(&:variant_id)
      return if variant_ids.uniq.size == variant_ids.size

      errors.add(:items, :duplicate_variant, message: Spree.t('errors.messages.duplicate_variant'))
    end
  end
end
