module Spree
  # Status transitions shared by PaymentSession and PaymentSetupSession —
  # the replacement for their (identical) state machines.
  #
  # Transitions are non-raising, matching the machines' non-bang events: the
  # webhook and synchronous completion paths race by design, and the loser
  # must land as a no-op `false`, never an exception. Each transition
  # publishes through the model's own publish_*_event method, exactly once —
  # only the writer whose conditional update moved the row publishes.
  #
  # A transition writes status alone — unlike the machine's save, it never
  # carries other dirty attributes along; a caller persists its own.
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
      return false unless transition_to('processing', from: %w[pending])

      publish_processing_event
      true
    end

    def complete
      return false unless transition_to('completed', from: %w[pending processing])

      publish_completed_event
      true
    end

    def fail
      return false unless transition_to('failed', from: %w[pending processing])

      publish_failed_event
      true
    end

    def cancel
      return false unless transition_to('canceled', from: %w[pending processing])

      publish_canceled_event
      true
    end

    def expire
      return false unless transition_to('expired', from: %w[pending processing])

      publish_expired_event
      true
    end

    private

    # A compare-and-swap on the status column, like Payment's processing
    # claim: the conditional update either moves the row or touches nothing,
    # and the loser is the writer whose update matched no row. Deliberately
    # not with_lock — its reload would wipe the session's association cache
    # mid-flow. The write is the transition event's, published by the
    # caller; the generic lifecycle updated event does not fire for status
    # flips.
    def transition_to(to, from:)
      if new_record?
        return false unless status.in?(from)

        self.status = to
        save!
        return true
      end

      claimed = self.class.where(id: id, status: from)
                          .update_all(status: to, updated_at: Time.current) == 1
      return false unless claimed

      self.status = to
      clear_attribute_changes(['status'])
      true
    end
  end
end
