module Spree
  class ReimbursementType < Spree::Base
    include Spree::NamedType

    KINDS = %w(Spree::ReimbursementType::Credit
               Spree::ReimbursementType::Exchange
               Spree::ReimbursementType::OriginalPayment
               Spree::ReimbursementType::StoreCredit).freeze
    ORIGINAL = 'original'.freeze

    has_many :return_items

    # This method will reimburse the return items based on however its child implements it
    # By default it takes a reimbursement, the return items it needs to reimburse, and if
    # it is a simulation or a real reimbursement. This should return an array
    def self.reimburse(_reimbursement, _return_items, _simulate)
      raise 'Implement me'
    end
  end
end
