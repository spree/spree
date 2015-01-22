module Spree
  module StateMachines
    class InventoryUnit
      include Statesman::Machine

      state :backordered
      state :on_hand, initial: true
      state :shipped

      event :fill_backorder do
        transition to: :on_hand, from: :backordered
      end

      event :return do
        transition to: :returned, from: :shipped
      end

      event :ship do
        transition to: :shipped, if: :allow_ship?
      end

      after_transition do |model, transition|
        model.state = transition.to_state
        model.save!
      end

      after_transition to: :on_hand, from: :backordered do |model, transition|
        model.fulfill_order
      end
    end
  end
end
