module Spree
  module StateMachines
    class Reimbursement
      include Statesman::Machine

      state :errored
      state :pending, initial: true
      state :reimbursed

      event :errored do
        transition to: :errored, from: :pending
      end

      event :reimbursed do
        transition to: :reimbursed, from: [:pending, :errored]
      end

      after_transition do |model, transition|
        model.state = transition.to_state
        model.save!
      end
    end
  end
end
