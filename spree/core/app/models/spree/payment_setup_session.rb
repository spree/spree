module Spree
  class PaymentSetupSession < Spree.base_class
    has_prefix_id :pss

    acts_as_paranoid

    include Spree::HasCustomFields

    self.event_prefix = 'payment_setup_session'

    publishes_lifecycle_events

    belongs_to :customer, class_name: Spree.customer_class.to_s, optional: true
    belongs_to :payment_method, class_name: 'Spree::PaymentMethod'
    belongs_to :payment_source, polymorphic: true, optional: true

    validates :payment_method, :status, presence: true
    validates :external_id, uniqueness: { scope: :payment_method_id }, allow_nil: true

    include Spree::PaymentSessionTransitions

    scope :active, -> { where(status: %w[pending processing]) }

    private

    def publish_processing_event
      publish_event('payment_setup_session.processing')
    end

    def publish_completed_event
      publish_event('payment_setup_session.completed')
    end

    def publish_failed_event
      publish_event('payment_setup_session.failed')
    end

    def publish_canceled_event
      publish_event('payment_setup_session.canceled')
    end

    def publish_expired_event
      publish_event('payment_setup_session.expired')
    end
  end
end
