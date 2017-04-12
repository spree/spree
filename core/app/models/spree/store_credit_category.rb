module Spree
  class StoreCreditCategory < Spree::Base
    validates :name, presence: true

    GIFT_CARD_CATEGORY_NAME = 'Gift Card'.freeze
    DEFAULT_NON_EXPIRING_TYPES = [GIFT_CARD_CATEGORY_NAME]

    def non_expiring?
      non_expiring_category_types.include? name
    end

    def non_expiring_category_types
      DEFAULT_NON_EXPIRING_TYPES | Spree::Config[:non_expiring_credit_types]
    end

    class << self
      def default_reimbursement_category(_options = {})
        Spree::StoreCreditCategory.first
      end
    end
  end
end
