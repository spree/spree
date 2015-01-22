module Spree
  module StateMachines
    class Payment
      include Statesman::Machine

      state :checkout, initial: true
      state :completed
      state :failed
      state :invalid
      state :pending
      state :processing
      state :void

      # With card payments this represents completing a purchase or capture transaction
      event :complete do
        transition from: [:processing, :pending, :checkout], to: :completed
      end

      # When processing during checkout fails
      event :failure do
        transition from: [:pending, :processing], to: :failed
      end

      # when the card brand isnt supported
      event :invalidate do
        transition from: [:checkout], to: :invalid
      end

      # With card payments this represents authorizing the payment
      event :pend do
        transition from: [:checkout, :processing], to: :pending
      end

      # With card payments, happens before purchase or authorization happens
      #
      # Setting it after creating a profile and authorizing a full amount will
      # prevent the payment from being authorized again once Order transitions
      # to complete
      event :started_processing do
        transition from: [:checkout, :pending, :completed, :processing], to: :processing
      end

      event :void do
        transition from: [:pending, :processing, :completed, :checkout], to: :void
      end

      after_transition do |payment, transition|
        payment.state = transition.to_state
        payment.state_changes.build(
          previous_state: transition.from_state,
          next_state:     transition.to_state,
          name:           'payment',
        )
        payment.save!
      end
    end
  end
end
