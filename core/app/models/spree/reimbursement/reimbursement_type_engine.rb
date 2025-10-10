module Spree
  class Reimbursement::ReimbursementTypeEngine
    include Spree::Reimbursement::ReimbursementTypeValidator

    class_attribute :refund_time_constraint
    self.refund_time_constraint = 90.days

    class_attribute :default_reimbursement_type
    self.default_reimbursement_type = Spree::ReimbursementType::OriginalPayment

    class_attribute :expired_reimbursement_type
    self.expired_reimbursement_type = Spree::ReimbursementType::OriginalPayment

    class_attribute :exchange_reimbursement_type
    self.exchange_reimbursement_type = Spree::ReimbursementType::Exchange

    def initialize(return_items)
      @return_items = return_items
      @reimbursement_type_hash = Hash.new { |h, k| h[k] = [] }
    end

    def calculate_reimbursement_types
      @return_items.each do |return_item|
        reimbursement_type = calculate_reimbursement_type(return_item)
        @reimbursement_type_hash[reimbursement_type] << return_item if reimbursement_type
      end

      @reimbursement_type_hash
    end

    private

    def calculate_reimbursement_type(return_item)
      return exchange_reimbursement_type if return_item.exchange_required?
      return return_item.override_reimbursement_type.class if return_item.override_reimbursement_type.present?
      if return_item.preferred_reimbursement_type.present?
        return valid_preferred_reimbursement_type?(return_item) ? return_item.preferred_reimbursement_type.class : nil
      end
      return expired_reimbursement_type if past_reimbursable_time_period?(return_item)

      default_reimbursement_type
    end
  end
end
