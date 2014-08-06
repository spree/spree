module Spree
  class ReimbursementType < Spree::Base
    include Spree::NamedType

    ORIGINAL = 'original'

    has_many :return_items

    # This method will reimburse the return items based on however it child implements it
    # By default it takes a reimbursement, the return items it needs to reimburse, and if
    # it is a simulation or a real reimbursement. This should return an array
    def self.reimburse(reimbursement, return_items, simulate)
      raise "Implement me"
    end
  end
end
