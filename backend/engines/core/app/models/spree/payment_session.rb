module Spree
  class PaymentSession < Spree.base_class
    has_prefix_id :ps

    acts_as_paranoid

    include Spree::Metafields

    self.event_prefix = 'payment_session'

    publishes_lifecycle_events

    belongs_to :order, class_name: 'Spree::Order'
    belongs_to :payment_method, class_name: 'Spree::PaymentMethod'
    belongs_to :customer, class_name: Spree.user_class.to_s, optional: true

    has_one :payment, class_name: 'Spree::Payment',
            foreign_key: :response_code,
            primary_key: :external_id

    validates :order, :payment_method, :external_id, :status, :currency, presence: true
    validates :external_id, uniqueness: { scope: [:order_id, :payment_method_id] }
    validates :amount, presence: true, numericality: { greater_than: 0 }

    state_machine :status, initial: :pending do
      state :pending
      state :processing
      state :completed
      state :failed
      state :canceled
      state :expired

      event :process do
        transition pending: :processing
      end

      event :complete do
        transition [:pending, :processing] => :completed
      end

      event :fail do
        transition [:pending, :processing] => :failed
      end

      event :cancel do
        transition [:pending, :processing] => :canceled
      end

      event :expire do
        transition [:pending, :processing] => :expired
      end

      after_transition to: :processing, do: :publish_processing_event
      after_transition to: :completed, do: :publish_completed_event
      after_transition to: :failed, do: :publish_failed_event
      after_transition to: :canceled, do: :publish_canceled_event
      after_transition to: :expired, do: :publish_expired_event
    end

    scope :not_expired, -> { where('expires_at IS NULL OR expires_at > ?', Time.current) }
    scope :active, -> { not_expired.where(status: %w[pending processing]) }

    before_validation :set_defaults_from_order, on: :create

    delegate :store, to: :order

    def amount_in_cents
      money.cents
    end

    def money
      @money ||= Spree::Money.new(amount, currency: currency)
    end

    def expired?
      expires_at.present? && expires_at <= Time.current
    end

    private

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
      return unless order

      self.amount ||= order.total_minus_store_credits if amount.blank? || amount.zero?
      self.currency ||= order.currency
      self.customer ||= order.user
    end
  end
end
