module Spree
  module StateMachines
    class Adjustment
      include Statesman::Machine

      state :closed
      state :open, initial: true

      event :close do
        transition from: :open, to: :closed
      end

      event :open do
        transition from: :closed, to: :open
      end

      after_transition do |model, transition|
        model.state = transition.to_state
        model.save!
      end
    end
  end
end
