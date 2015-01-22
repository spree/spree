module Spree
  module StateMachines
    class AcceptanceStatus
      include Statesman::Machine

      state :accepted
      state :manual_intervention_required
      state :pending, initial: true
      state :received
      state :rejected

      after_transition do |model, transition|
        model.persist_acceptance_status_errors
        model.acceptance_status = transition.to_state
        model.save!
      end

      after_transition to: :received do |model, transition|
        model.attempt_accept
        model.process_inventory_unit!
      end

      event :attempt_accept do
        transition to: :accepted, from: :accepted
        transition to: :accepted, from: :pending, if: ->(return_item) { return_item.eligible_for_return? }
        transition to: :manual_intervention_required, from: :pending, if: ->(return_item) { return_item.requires_manual_intervention? }
        transition to: :rejected, from: :pending
      end

      # bypasses eligibility checks
      event :accept do
        transition to: :accepted, from: [:accepted, :pending, :manual_intervention_required]
      end

      # bypasses eligibility checks
      event :reject do
        transition to: :rejected, from: [:accepted, :pending, :manual_intervention_required]
      end

      # bypasses eligibility checks
      event :require_manual_intervention do
        transition to: :manual_intervention_required, from: [:accepted, :pending, :manual_intervention_required]
      end
    end
  end
end
