module Spree
  # Who a gift card line is for. The cards a paid order issues for the line
  # are emailed here; a line without a recipient sends them to the order's
  # email instead.
  class GiftCardRecipient < Spree.base_class
    has_prefix_id :gcr

    # Registered before the concern's own fallback to the request's store,
    # so the row always takes the store of the purchase it belongs to.
    before_validation -> { self.store ||= line_item&.order&.store || line_item&.cart&.store }
    include Spree::SingleStoreResource

    # How far ahead a buyer may schedule the email, as on Shopify.
    MAX_SEND_AHEAD = 90.days

    ATTRIBUTES = %w[email name message send_at].freeze

    belongs_to :line_item, class_name: 'Spree::LineItem', inverse_of: :gift_card_recipient

    normalizes :email, with: ->(value) { value.to_s.strip.downcase.presence }
    normalizes :name, :message, with: ->(value) { value.to_s.strip.presence }

    validates :email, presence: true, email: true
    validates :name, length: { maximum: 255 }
    validates :message, length: { maximum: 500 }
    validates :line_item_id, uniqueness: { scope: spree_base_uniqueness_scope }
    validate :send_at_within_window, if: :send_at_changed?
    validate :line_item_must_be_gift_card

    self.whitelisted_ransackable_attributes = %w[email]

    # The recipient fields of a request payload, string-keyed.
    #
    # @param attributes [Hash, ActionController::Parameters, nil]
    # @return [Hash]
    def self.permitted(attributes)
      attributes.to_h.stringify_keys.slice(*ATTRIBUTES)
    end

    # Whether two recipient payloads name the same person with the same
    # message, which is when two adds of a denomination share one line.
    #
    # @param attributes [Hash, nil]
    # @return [Boolean]
    def same_as?(attributes)
      return false if attributes.blank?

      other = self.class.new(self.class.permitted(attributes))
      ATTRIBUTES.all? { |attribute| public_send(attribute) == other.public_send(attribute) }
    end

    private

    def send_at_within_window
      return if send_at.nil?

      errors.add(:send_at, :too_far_ahead) if send_at > MAX_SEND_AHEAD.from_now
    end

    def line_item_must_be_gift_card
      errors.add(:line_item, :not_a_gift_card) unless line_item&.gift_card?
    end
  end
end
