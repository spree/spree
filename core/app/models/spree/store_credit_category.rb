class Spree::StoreCreditCategory < ActiveRecord::Base
  def non_expiring?
    non_expiring_category_types.include? name
  end

  def non_expiring_category_types
    Spree::StoreCredits::Configuration.non_expiring_credit_types
  end

  class << self
    def default_reimbursement_category(options = {})
      Spree::StoreCreditCategory.first
    end
  end
end
