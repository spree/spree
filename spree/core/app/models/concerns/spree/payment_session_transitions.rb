module Spree
  # Status transitions shared by PaymentSession and PaymentSetupSession —
  # the replacement for their (identical) state machines.
  #
  # Transitions are non-raising, matching the machines' non-bang events: the
  # webhook and synchronous completion paths race by design, and the loser
  # must land as a no-op `false`, never an exception. Each transition
  # publishes through the model's own publish_*_event method.
  module PaymentSessionTransitions
    extend ActiveSupport::Concern

    included do
      include Spree::HasStatus
      has_status :pending, :processing, :completed, :failed, :canceled, :expired,
                 default: :pending
    end

    # Guards preserved from the machine's transition graph.
    def can_process?
      pending?
    end

    %w[complete fail cancel expire].each do |transition|
      define_method(:"can_#{transition}?") { pending? || processing? }
    end

    def process
      return false unless can_process?

      update!(status: 'processing')
      publish_processing_event
      true
    end

    def complete
      return false unless can_complete?

      update!(status: 'completed')
      publish_completed_event
      true
    end

    def fail
      return false unless can_fail?

      update!(status: 'failed')
      publish_failed_event
      true
    end

    def cancel
      return false unless can_cancel?

      update!(status: 'canceled')
      publish_canceled_event
      true
    end

    def expire
      return false unless can_expire?

      update!(status: 'expired')
      publish_expired_event
      true
    end
  end
end
