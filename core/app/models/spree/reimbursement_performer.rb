module Spree

  class ReimbursementPerformer

    class << self
      class_attribute :reimbursement_type_engine
      self.reimbursement_type_engine = Spree::Reimbursement::ReimbursementTypeEngine

      # Simulate performing the reimbursement without actually saving anything or refunding money, etc.
      # This must return an array of objects that respond to the following methods:
      # - #description
      # - #display_amount
      # so they can be displayed in the Admin UI appropriately.
      def simulate(reimbursement)
        execute(reimbursement, true)
      end

      # Actually perform the reimbursement
      def perform(reimbursement)
        execute(reimbursement, false)
      end

      private

      def execute(reimbursement, simulate)
        reimbursement_type_hash = calculate_reimbursement_types(reimbursement)

        reimbursement_type_hash.flat_map do |reimbursement_type, return_items|
          reimbursement_type.reimburse(reimbursement, return_items, simulate)
        end
      end

      def calculate_reimbursement_types(reimbursement)
        # Engine returns hash of preferred reimbursement types pointing at return items
        # {Spree::ReimbursementType::OriginalPayment => [ReturnItem, ...], Spree::ReimbursementType::Exchange => [ReturnItem, ...]}
        reimbursement_type_engine.new(reimbursement.return_items).calculate_reimbursement_types
      end

    end

  end

end
