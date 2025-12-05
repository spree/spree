module Spree
  class GiftCard < Spree.base_class
    extend DisplayMoney
    include Spree::SingleStoreResource
    include Spree::Metafields
    include Spree::Security::GiftCards if defined?(Spree::Security::GiftCards)

    #
    # State machine
    #
    state_machine :state, initial: :active do
      event :cancel do
        transition active: :canceled
      end

      event :redeem do
        transition active: :redeemed
        transition partially_redeemed: :redeemed
      end
      after_transition to: :redeemed, do: :after_redeem
      after_transition to: :redeemed, do: :send_gift_card_redeemed_event

      event :partial_redeem do
        transition active: :partially_redeemed
        transition partially_redeemed: :partially_redeemed
      end
      after_transition to: :partially_redeemed, do: :send_gift_card_partial_redeemed_event
    end

    #
    # Validations
    #
    validates :code, presence: true, uniqueness: { scope: :store_id }
    validates :store, :currency, presence: true
    validates :amount, presence: true, numericality: { greater_than: 0 }
    validates :amount_used, :amount_authorized, presence: true, numericality: { greater_than_or_equal_to: 0 }

    #
    # Associations
    #
    belongs_to :store, class_name: 'Spree::Store'
    belongs_to :user, class_name: Spree.user_class.to_s, optional: true
    belongs_to :created_by, class_name: Spree.admin_user_class.to_s, optional: true
    belongs_to :batch, class_name: 'Spree::GiftCardBatch', optional: true, foreign_key: :gift_card_batch_id

    has_many :store_credits, class_name: 'Spree::StoreCredit', as: :originator
    has_many :orders, inverse_of: :gift_card, class_name: 'Spree::Order'
    has_many :users, through: :orders, class_name: Spree.user_class.to_s

    #
    # Scopes
    #
    scope :active, -> { where(state: [:active, :partially_redeemed]).where(expires_at: [nil,  Date.tomorrow..]) }
    scope :expired, -> { where(state: :active).where(expires_at: ..Date.current) }
    scope :redeemed, -> { where(state: [:redeemed]) }
    scope :partially_redeemed, -> { where(state: [:partially_redeemed]) }

    #
    # Ransack
    #
    self.whitelisted_ransackable_attributes = %w[code user_id state]
    self.whitelisted_ransackable_associations = %w[users orders batch]
    self.whitelisted_ransackable_scopes = %w[active expired redeemed partially_redeemed]

    auto_strip_attributes :code

    #
    # Callbacks
    #
    before_validation :generate_code
    before_validation :normalize_code
    before_validation :set_currency
    before_destroy :ensure_can_be_deleted

    #
    # Money
    #
    money_methods :amount, :amount_used, :amount_authorized, :amount_remaining

    # Sets the amount
    # @param amount [String]
    def amount=(amount)
      self[:amount] = Spree::LocalizedNumber.parse(amount)
    end

    # Calculates the remaining amount
    # @return [Decimal]
    def amount_remaining
      amount - amount_used - amount_authorized
    end

    delegate :email, to: :user, prefix: true, allow_nil: true

    def self.json_api_columns
      %w[code amount expires_at]
    end

    # Checks if the gift card is editable
    # @return [Boolean]
    def editable?
      active?
    end

    # Checks if the gift card can be deleted
    # @return [Boolean]
    def can_be_deleted?
      !redeemed? && !partially_redeemed?
    end

    # Displays the code in uppercase, eg. ABC1234
    # @return [String]
    def display_code
      code.upcase
    end

    # Checks if the gift card is expired
    # @return [Boolean]
    def expired?
      !redeemed? && expires_at.present? && expires_at <= Date.current
    end

    # Checks if the gift card is active, i.e. not expired and not redeemed
    # @return [Boolean]
    def active?
      super && !expired?
    end

    # Displays state as expired if the gift card is expired, otherwise displays the state
    # @return [String]
    def display_state
      if expired?
        :expired
      else
        state
      end.to_s
    end

    def to_csv(_store = nil)
      Spree::CSV::GiftCardPresenter.new(self).call
    end

    private

    def generate_code
      return if code.present?

      self.code = loop do
        random_token = SecureRandom.hex(8).downcase
        break random_token unless self.class.exists?(code: random_token, store_id: store_id)
      end
    end

    def normalize_code
      self.code = code.downcase if code.present?
    end

    def after_redeem
      update!(redeemed_at: Time.current)
    end

    def send_gift_card_redeemed_event
      publish_event('gift_card.redeem')
    end

    def send_gift_card_partial_redeemed_event
      publish_event('gift_card.partial_redeem')
    end

    def ensure_can_be_deleted
      return if can_be_deleted?

      errors.add(:base, :cannot_destroy_used_gift_card)
      throw(:abort)
    end

    def set_currency
      self.currency ||= store&.default_currency
    end
  end
end
