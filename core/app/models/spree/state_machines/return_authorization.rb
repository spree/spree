module Spree
  module StateMachines
    class ReturnAuthorization
      include Statesman::Machine

      state :authorized, initial: true
      state :canceled

      event :cancel do
        transition to: :canceled, from: :authorized
      end

      after_transition do |model, transition|
        model.state = transition.to_state
        model.save!
      end

      before_transition to: :canceled do |model, transition|
        model.cancel_return_items
      end
    end
  end
end
