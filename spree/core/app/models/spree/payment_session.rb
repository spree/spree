module Spree
  class PaymentSession < Spree.base_class
    has_prefix_id :ps

    acts_as_paranoid

    include Spree::HasCustomFields

    self.event_prefix = 'payment_session'

    publishes_lifecycle_events

    belongs_to :order, class_name: 'Spree::Order', optional: true
    belongs_to :cart, class_name: 'Spree::Cart', optional: true, inverse_of: :payment_sessions
    belongs_to :payment_method, class_name: 'Spree::PaymentMethod'
    belongs_to :customer, class_name: Spree.customer_class.to_s, optional: true

    has_one :payment, class_name: 'Spree::Payment',
            foreign_key: :response_code,
            primary_key: :external_id

    validates :external_id, :status, :currency, presence: true
    validate :exactly_one_owner
    validates :external_id, uniqueness: { scope: [:order_id, :payment_method_id] }
    validates :amount, presence: true, numericality: { greater_than: 0 }

    include Spree::PaymentSessionTransitions

    scope :not_expired, -> { where('expires_at IS NULL OR expires_at > ?', Time.current) }
    scope :active, -> { not_expired.where(status: %w[pending processing]) }

    before_validation :set_defaults_from_order, on: :create

    delegate :store, to: :owner

    def amount_in_cents
      money.cents
    end

    def money
      @money ||= Spree::Money.new(amount, currency: currency)
    end

    def expired?
      expires_at.present? && expires_at <= Time.current
    end

    # Creates or finds the Spree::Payment record for this session.
    # Gateway subclasses can override this in their PaymentSession subclass
    # to handle gateway-specific source creation (credit cards, wallets, etc).
    #
    # @param metadata [Hash] gateway-specific metadata
    # @return [Spree::Payment] the payment record
    def find_or_create_payment!(metadata = {})
      # An unsaved session has no identity to key a payment to, and nothing
      # has settled against it.
      return unless persisted?

      # Session payments carry no Spree-side source unless the gateway builds
      # one, so the requirement is skipped on every load, not just at creation
      # — a later capture webhook transitions the same row and would otherwise
      # fail source validation.
      return skip_source_requirement(payment) if payment.present?

      # Keyed on the gateway's own identifier alone. Never on the amount: a
      # session whose amount moved is still the same intent, and a second row
      # for it would both double the order's money and collide with the unique
      # index on (owner, payment_method, response_code).
      created = owner.payments.find_or_create_by!(
        payment_method: payment_method,
        response_code: external_id
      ) do |new_payment|
        new_payment.amount = amount
        new_payment.skip_source_requirement = true
        new_payment.source = payment_source_for_settlement
        apply_settlement_metadata(new_payment, metadata)
      end

      skip_source_requirement(created)
    rescue ActiveRecord::RecordNotUnique
      # The webhook and the customer's synchronous return race by design;
      # whoever loses the insert finds the row the winner created.
      skip_source_requirement(
        owner.payments.find_by!(
          payment_method: payment_method,
          response_code: external_id
        )
      )
    end

    # The payment source to attach when the payment row is first created.
    # Gateways holding the instrument (a card, a mandate) build one here so
    # the payment shows a brand and last four digits; those with nothing to
    # represent return nil and the payment stands on its own.
    #
    # Called inside the settlement lock, so it must not perform provider I/O
    # — warm anything it needs in +prepare_for_settlement!+.
    #
    # @return [Spree::PaymentSource, nil]
    def payment_source_for_settlement
      nil
    end

    # Records gateway-specific detail on the new payment. Overridden by
    # gateways that carry references worth keeping (a charge id, a mandate).
    #
    # @param payment [Spree::Payment] unsaved
    # @param metadata [Hash] whatever the settling caller passed
    # @return [void]
    def apply_settlement_metadata(payment, metadata)
      payment.metadata.merge!(metadata.stringify_keys) if metadata.present?
    end

    # Fetches whatever settlement will need from the provider, so a caller
    # that settles inside a lock (the webhook path) holds it across no
    # provider I/O. Gateway session subclasses override; no-op by default.
    #
    # @return [Spree::PaymentSession] self
    def prepare_for_settlement!
      self
    end

    # The one place a session settles its payment — used by both routes a
    # settled session is noticed on (the storefront confirm call and the
    # gateway webhook), so the two can never drift apart.
    #
    # Serialized on the owner's row: the two routes can race, and the
    # completed? guard alone is check-then-act — two concurrent settlements
    # would each record a capture event, doubling captured_amount. The lock
    # wraps only the local settlement, never gateway I/O — callers fetch
    # provider data first (the confirm path as it verifies the session, the
    # webhook path via prepare_for_settlement!) — and nests as a no-op inside
    # HandleWebhook's own owner lock.
    #
    # @param captured [Boolean] whether the gateway reports the funds as
    #   captured; false means authorized only, so the payment pends
    # @param metadata [Hash] gateway-specific metadata for payment creation
    # @return [Spree::Payment, nil]
    def settle_payment!(captured:, metadata: {})
      owner.with_lock do
        settled_payment = find_or_create_payment!(metadata)

        if settled_payment.present?
          # DB-state recheck, deliberately not a reload — the payment may have
          # been cached on this instance before the lock (a concurrent
          # settlement could have completed it), but reload would discard
          # in-memory state like skip_source_requirement.
          already_completed = settled_payment.completed? ||
                              Spree::Payment.where(id: settled_payment.id, status: 'completed').exists?

          settled_payment.confirm!(captured: captured) unless already_completed
        end

        settled_payment
      end
    end

    # @return [Spree::Cart, Spree::Order, nil]
    def owner
      order || cart
    end

    # Bridge for legacy callers assigning +current_order+ (now a Spree::Cart)
    # to the order association — routes carts to the cart FK instead.
    def order=(record)
      if record.is_a?(Spree::Cart)
        self.cart = record
        super(nil)
      else
        super
      end
    end

    # Assigns the owning record to the matching association (cart or order),
    # clearing the other one. Lets gateways stay owner-agnostic.
    #
    # @param record [Spree::Cart, Spree::Order]
    def owner=(record)
      if record.is_a?(Spree::Cart)
        self.cart = record
        self.order = nil
      else
        self.order = record
        self.cart = nil
      end
    end

    private

    # Only for payments with no Spree-side source — a gateway that does record
    # one (Stripe's card sources) leaves it untouched.
    def skip_source_requirement(payment_record)
      payment_record.skip_source_requirement = true if payment_record&.source.blank?
      payment_record
    end

    def exactly_one_owner
      errors.add(:base, :exactly_one_of_cart_or_order, message: Spree.t('errors.messages.exactly_one_of_cart_or_order')) unless [order, cart].compact.one?
    end

    def publish_processing_event
      publish_event('payment_session.processing')
    end

    def publish_completed_event
      publish_event('payment_session.completed')
    end

    def publish_failed_event
      publish_event('payment_session.failed')
    end

    def publish_canceled_event
      publish_event('payment_session.canceled')
    end

    def publish_expired_event
      publish_event('payment_session.expired')
    end

    def set_defaults_from_order
      return unless owner

      # Capped at what checkout collects, so a gateway session on deposit
      # terms asks the buyer for the deposit rather than the whole total.
      self.amount ||= default_collectable_amount if amount.blank? || amount.zero?
      self.currency ||= owner.currency
      self.customer ||= owner.customer
    end

    def default_collectable_amount
      collectable = owner.total_minus_store_credits
      return collectable unless owner.respond_to?(:amount_due_at_checkout)

      [owner.amount_due_at_checkout, collectable].min
    end
  end
end
