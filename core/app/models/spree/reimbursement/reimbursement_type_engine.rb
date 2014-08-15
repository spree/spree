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
      @reimbursement_type_hash = Hash.new {|h,k| h[k] = Array.new }
    end

    def calculate_reimbursement_types
      @return_items.each do |return_item|
        if return_item.exchange_required?
          add_reimbursement_type(return_item, exchange_reimbursement_type)
        elsif return_item.override_reimbursement_type.present?
          add_reimbursement_type(return_item, return_item.override_reimbursement_type.class)
        elsif return_item.preferred_reimbursement_type.present?
          next unless valid_preferred_reimbursement_type?(return_item)
          add_reimbursement_type(return_item, return_item.preferred_reimbursement_type.class)
        elsif past_reimbursable_time_period?(return_item)
          add_reimbursement_type(return_item, expired_reimbursement_type)
        else
          add_reimbursement_type(return_item, default_reimbursement_type)
        end
      end

      @reimbursement_type_hash
    end

    private

    def add_reimbursement_type(return_item, reimbursement_type)
      return unless reimbursement_type
      @reimbursement_type_hash[reimbursement_type] << return_item
    end
  end
end
