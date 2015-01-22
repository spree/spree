module Spree
  module StateMachines
    class ReceptionStatus
      include Statesman::Machine

      state :awaiting, initial: true
      state :cancelled
      state :given_to_customer
      state :received

      after_transition do |model, transition|
        model.reception_status = transition.to_state
        model.save!
      end

      after_transition to: :received do |model, transition|
        model.attempt_accept
        model.process_inventory_unit!
      end

      event :cancel do
        transition to: :cancelled, from: :awaiting
      end

      event :give do
        transition to: :given_to_customer, from: :awaiting
      end

      event :receive do
        transition to: :received, from: :awaiting
      end
    end
  end
end
