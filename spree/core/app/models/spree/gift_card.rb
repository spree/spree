module Spree
  class GiftCard < Spree.base_class
    has_prefix_id :gc

    extend DisplayMoney
    include Spree::SingleStoreResource
    include Spree::HasCustomFields
    include Spree::Security::GiftCards if defined?(Spree::Security::GiftCards)

    publishes_lifecycle_events

    #
    # Status
    #
    # No state machine — redemption and cancellation run through the
    # Spree::GiftCards workflows (docs/plans/6.0-service-workflows.md).
    # +active?+ is defined below rather than generated: a card past its expiry
    # date still holds the `active` status but is not usable, and every caller
    # asking "is this card active" means the latter.
    include Spree::HasStatus
    has_status :active, :partially_redeemed, :redeemed, :canceled, default: :active

    #
    # Validations
    #
    validates :code, presence: true, uniqueness: { scope: :store_id }
    validates :currency, presence: true
    validates :amount, presence: true, numericality: { greater_than: 0 }
    validates :amount_used, :amount_authorized, presence: true, numericality: { greater_than_or_equal_to: 0 }

    #
    # Associations
    #
    belongs_to :store, class_name: 'Spree::Store'
    belongs_to :customer, class_name: Spree.customer_class.to_s, optional: true
    include Spree::DeprecatedCustomerAlias
    belongs_to :created_by, class_name: Spree.admin_user_class.to_s, optional: true
    belongs_to :batch, class_name: 'Spree::GiftCardBatch', optional: true, foreign_key: :gift_card_batch_id

    has_many :store_credits, class_name: 'Spree::StoreCredit', as: :originator
    has_many :orders, inverse_of: :gift_card, class_name: 'Spree::Order'
    has_many :carts, inverse_of: :gift_card, class_name: 'Spree::Cart'
    has_many :customers, through: :orders, source: :customer
    has_many :users, through: :orders, source: :customer, deprecated: true

    #
    # Scopes
    #
    # These deliberately override the plain status scopes has_status generates:
    # usability is status *and* expiry, and a partially redeemed card is still
    # spendable.
    scope :active, -> { where(status: [:active, :partially_redeemed]).where(expires_at: [nil,  Date.tomorrow..]) }
    scope :expired, -> { where(status: :active).where(expires_at: ..Date.current) }
    scope :redeemed, -> { where(status: [:redeemed]) }
    scope :partially_redeemed, -> { where(status: [:partially_redeemed]) }

    #
    # Ransack
    #
    ransack_alias :state, :status # @deprecated filter alias — removed in 6.1
    self.whitelisted_ransackable_attributes = %w[code customer_id status state gift_card_batch_id created_by_id]
    # `users` is the pre-6.0 name for `customers` — removed in 6.1.
    self.whitelisted_ransackable_associations = %w[customers users orders batch]
    self.whitelisted_ransackable_scopes = %w[active expired redeemed partially_redeemed]

    normalizes :code, with: ->(value) { value&.to_s&.squish&.presence }

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

    delegate :email, to: :customer, prefix: true, allow_nil: true

    def self.json_api_columns
      %w[code amount expires_at]
    end

    # Carts and draft orders currently holding part of this card's balance.
    # Applying a card draws it down before anything is paid for, so a card
    # left on an abandoned cart keeps money locked up until that record is
    # completed or the card is taken off it. Spree::GiftCards::Apply releases
    # these holds so the customer presenting the code can spend it again.
    #
    # A hold in the middle of a completion attempt is never returned — see
    # +holds_being_completed+. The two readers partition the same set, so a
    # hold this one omits for that reason always appears in the other.
    #
    # @param except [Spree::Cart, Spree::Order, nil] the record being applied
    #   to, which is not a stale hold
    # @return [Array<Spree::Cart, Spree::Order>]
    def open_holds(except: nil)
      all_holds(except: except).reject { |hold| claimed_by_completion?(hold) }
    end

    # Holds this card cannot be taken from because a completion attempt holds
    # them — the balance frees up on its own once the claim resolves or goes
    # stale, so a caller refused for this reason can tell the customer to
    # retry rather than that the card is spent.
    #
    # @param except [Spree::Cart, Spree::Order, nil]
    # @return [Array<Spree::Cart, Spree::Order>]
    def holds_being_completed(except: nil)
      all_holds(except: except).select { |hold| claimed_by_completion?(hold) }
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
      status == 'active' && !expired?
    end

    # Displays status as expired if the gift card is expired, otherwise the
    # stored status. Expiry is derived from a date rather than stored, so it
    # never appears in the column.
    # @return [String]
    def display_status
      if expired?
        :expired
      else
        status
      end.to_s
    end

    # @deprecated use +display_status+ — removed in 6.1
    def display_state
      Spree::Deprecation.warn('Spree::GiftCard#display_state is deprecated and will be removed in Spree 6.1. Use #display_status instead.')
      display_status
    end

    # @deprecated read +status+ — removed in 6.1
    def state
      Spree::Deprecation.warn('Spree::GiftCard#state is deprecated and will be removed in Spree 6.1. Use #status instead.')
      status
    end

    # @deprecated write +status+ — removed in 6.1
    def state=(value)
      Spree::Deprecation.warn('Spree::GiftCard#state= is deprecated and will be removed in Spree 6.1. Use #status= instead.')
      self.status = value
    end

    # @deprecated Call Spree.gift_card_redeem_workflow — removed in 6.1.
    #   The workflow decides full versus partial redemption from the balance,
    #   so both old verbs land on it.
    def redeem!
      Spree::Deprecation.warn('Spree::GiftCard#redeem! is deprecated and will be removed in Spree 6.1. Call Spree.gift_card_redeem_workflow instead.')
      run_gift_card_workflow(Spree.gift_card_redeem_workflow)
    end
    alias partial_redeem! redeem!

    # @deprecated Call Spree.gift_card_cancel_workflow — removed in 6.1.
    def cancel!
      Spree::Deprecation.warn('Spree::GiftCard#cancel! is deprecated and will be removed in Spree 6.1. Call Spree.gift_card_cancel_workflow instead.')
      run_gift_card_workflow(Spree.gift_card_cancel_workflow)
    end

    def to_csv(store = nil)
      Spree::CSV::GiftCardPresenter.new(self, store || self.store).call
    end

    private

    # Ordered by id so concurrent applies lock holds in the same sequence and
    # cannot form a deadlock cycle between two carts.
    def all_holds(except: nil)
      holds = carts.incomplete.order(:id).to_a +
              orders.incomplete.where.not(status: 'canceled').includes(:cart).order(:id).to_a

      holds.reject { |hold| same_record?(hold, except) }
    end

    def same_record?(hold, other)
      other.present? && hold.class == other.class && hold.id == other.id
    end

    # A record at the gateway has fixed totals and money in flight; taking its
    # gift card away mid-charge would place an order that no longer adds up.
    # Checkout stamps the claim on the cart and then copies the card onto a
    # draft order, so the draft is protected through its originating cart —
    # that copy is the window where real money is moving.
    def claimed_by_completion?(hold)
      case hold
      when Spree::Cart then hold.completion_claimed?
      else hold.cart&.completion_claimed? || false
      end
    end

    # Mirrors the machine's bang events: an illegal move raised, so a rejected
    # workflow raises here too rather than returning quietly.
    def run_gift_card_workflow(workflow)
      result = workflow.call(gift_card: self)

      if result.failure?
        # ResultError#to_s unwraps an ActiveModel::Errors into its full
        # messages; its `value` would inspect the object into the message.
        errors.add(:base, result.error.to_s)
        raise ActiveRecord::RecordInvalid, self
      end

      true
    end

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
