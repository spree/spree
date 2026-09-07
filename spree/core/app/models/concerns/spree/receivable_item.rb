module Spree
  # A line on a document that expects goods to arrive: how many were promised,
  # and how many the warehouse actually counted.
  #
  # The promised quantity has a different name on each document —
  # `quantity_shipped` on a stock transfer, `quantity_ordered` on a purchase
  # order — because the merchant's own vocabulary differs. Including classes
  # name their column once in `expected_quantity_attribute` and everything
  # here reads through {#quantity_expected}.
  module ReceivableItem
    extend ActiveSupport::Concern

    class_methods do
      # @param attribute [Symbol] the column holding the promised quantity
      def expects_quantity_in(attribute)
        class_attribute :expected_quantity_attribute, default: attribute.to_sym,
                                                      instance_writer: false
      end
    end

    included do
      # `with_deleted`: a line outlives the variant it names, the same way the
      # movement ledger outlives the level it describes. Without this a
      # discontinued SKU takes the whole document out of the API with it.
      belongs_to :variant, -> { with_deleted }, class_name: 'Spree::Variant'

      validates :quantity_received, numericality: {
        greater_than_or_equal_to: 0, only_integer: true
      }
      validate :received_does_not_exceed_expected

      delegate :name, :sku, to: :variant, prefix: true, allow_nil: true
    end

    # How many units this line promised.
    #
    # @return [Integer]
    def quantity_expected
      public_send(self.class.expected_quantity_attribute).to_i
    end

    # How many are still owed.
    #
    # @return [Integer]
    def outstanding
      quantity_expected - quantity_received.to_i
    end

    # Whether fewer units arrived than were promised.
    #
    # @return [Boolean]
    def under_received?
      outstanding.positive?
    end

    private

    # The error goes on `quantity_received` because that is the value the
    # caller sent: a receive of twelve against ten shipped is a miscount at
    # the receiving dock, not a retrospective error in what left.
    def received_does_not_exceed_expected
      return if quantity_received.blank? || quantity_expected.zero?
      return if quantity_received.to_i <= quantity_expected

      errors.add(:quantity_received, :cannot_exceed_expected,
                 message: Spree.t('errors.messages.received_exceeds_expected', expected: quantity_expected))
    end
  end
end
