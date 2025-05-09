module Spree
  class GiftCard < Spree.base_class
    extend DisplayMoney
    include Spree::SingleStoreResource
    include Spree::Security::GiftCards if defined?(Spree::Security::GiftCards)

    enum :state, { active: 0, redeemed: 1, canceled: 2, redeemed_by_order: 3, partialy_redeemed: 4 }

    validates :code, presence: true, uniqueness: true
    validates :amount, numericality: { greater_than: 0 }
    validates :minimum_order_amount, numericality: { greater_than_or_equal_to: 0 }
    validates :expires_at, comparison: { greater_than: Date.current + 1.day }, allow_nil: true, unless: :skip_expires_at_validation
    validates :user, presence: true, if: -> { user_id.present? }

    belongs_to :user, class_name: Spree.user_class.to_s, optional: true
    belongs_to :store, class_name: 'Spree::Store'
    belongs_to :batch, class_name: 'Spree::GiftCardBatch', optional: true, foreign_key: :gift_card_batch_id
    has_many :store_credits, class_name: 'Spree::StoreCredit'

    if defined?(Spree::Vendor)
      has_many :orders, -> { without_vendor }, through: :store_credits, source: :orders
    else
      has_many :orders, through: :store_credits, source: :orders
    end

    has_many :users, through: :orders, class_name: Spree.user_class.to_s

    scope :active, -> { where(state: [:active, :partialy_redeemed]).where(expires_at: [nil, Time.current..]) }
    scope :expired, -> { where(state: :active).where(expires_at: ..Time.current) }
    scope :redeemed, -> { where(state: [:redeemed, :redeemed_by_order]) }

    self.whitelisted_ransackable_attributes = %w[code user_id]
    self.whitelisted_ransackable_associations = %w[users orders batch]

    auto_strip_attributes :code

    before_validation :generate_code
    before_validation :normalize_code
    after_validation :set_amount_remaining

    before_destroy :ensure_can_be_deleted

    money_methods :amount, :used_amount, :amount_remaining, :minimum_order_amount

    delegate :email, to: :user, prefix: true, allow_nil: true

    def self.json_api_columns
      %w[code amount minimum_order_amount expires_at]
    end

    def editable?
      active? || canceled?
    end

    def can_be_deleted?
      editable?
    end

    def generate_code
      return if code.present?

      self.code = loop do
        random_token = SecureRandom.hex(8).to_s.upcase
        break random_token unless self.class.exists?(code: random_token, store_id: store_id)
      end
    end

    def normalize_code
      self.code = code.downcase if code.present?
    end

    def display_code
      code.upcase
    end

    def expired?
      !redeemed? && expires_at.present? && expires_at < Time.current
    end

    def active?
      super && !expired?
    end

    def display_state
      if expired?
        :expired
      else
        state
      end.to_s
    end

    def used_amount
      @used_amount ||= amount - amount_remaining
    end

    def apply!(amount:, user:, currency:)
      amount_applied = [amount, amount_remaining].min
      return unless amount_applied.positive?

      transaction do
        store_credit = Spree::StoreCredit.create!(
          gift_card: self,
          store: store,
          user: user,
          amount: amount_applied,
          currency: currency,
          expires_at: expires_at
        )

        self.amount_remaining -= amount_applied
        save!

        store_credit
      end
    end

    def undo_apply!(amount:)
      transaction do
        self.amount_remaining = [amount_remaining + amount, self.amount].min
        self.state = amount_remaining == self.amount ? :active : :partialy_redeemed
        self.skip_expires_at_validation = true
        save!

        self.skip_expires_at_validation = false

        store_credit = store_credits.available.find_by(amount: amount)
        store_credit.destroy!
      end
    end

    def redeem!
      new_state = amount_remaining.positive? ? :partialy_redeemed : :redeemed
      update!(state: new_state)
    end

    private

    attr_accessor :skip_expires_at_validation

    def set_amount_remaining
      return unless active?
      return if amount_remaining_changed?

      self.amount_remaining = amount
    end

    def ensure_can_be_deleted
      return if can_be_deleted?

      errors.add(:base, :cannot_destroy_used_gift_card)
      throw(:abort)
    end
  end
end
