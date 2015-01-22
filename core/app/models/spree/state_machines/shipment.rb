module Spree
  module StateMachines
    class Shipment
      include Statesman::Machine

      state :canceled
      state :pending, initial: true
      state :ready
      state :shipped

      event :cancel do
        transition to: :canceled, from: :pending
        transition to: :canceled, from: :ready
      end

      event :pend do
        transition from: :ready, to: :pending
      end

      event :ready do
        transition from: :pending, to: :ready, if: lambda { |shipment|
          # Fix for #2040
          shipment.determine_state(shipment.order) == 'ready'
        }
      end

      event :ship do
        transition from: :canceled, to: :shipped
        transition from: :ready, to: :shipped
      end

      event :resume do
        transition from: :canceled, to: :ready, if: lambda { |shipment|
          shipment.determine_state(shipment.order) == :ready
        }
        transition from: :canceled, to: :pending, if: lambda { |shipment|
          shipment.determine_state(shipment.order) == :ready
        }
        transition from: :canceled, to: :pending
      end

      after_transition do |shipment, transition|
        shipment.state = transition.to_state
        shipment.state_changes.build(
          previous_state: transition.from_state,
          next_state:     transition.to_state,
          name:           'shipment',
        )
        shipment.save!
      end

      after_transition from: :canceled, to: [:pending, :ready, :shipped] do |shipment, transition|
        shipment.after_resume
      end

      after_transition to: :canceled do |shipment, transition|
        shipment.after_cancel
      end

      after_transition to: :shipped do |shipment, transition|
        shipment.after_ship
      end
    end
  end
end
