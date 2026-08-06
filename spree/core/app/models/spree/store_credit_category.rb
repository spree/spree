module Spree
  class StoreCreditCategory < Spree.base_class
    has_prefix_id :sccat

    validates :name, presence: true

    before_destroy :validate_not_used

    GIFT_CARD_CATEGORY_NAME = 'Gift Card'.freeze
    DEFAULT_NON_EXPIRING_TYPES = [GIFT_CARD_CATEGORY_NAME]

    self.whitelisted_ransackable_attributes = %w[name]

    def non_expiring?
      non_expiring_category_types.include? name
    end

    def non_expiring_category_types
      DEFAULT_NON_EXPIRING_TYPES | Spree::Config[:non_expiring_credit_types]
    end

    def store_credit_category_used?
      Spree::StoreCredit.exists?(category_id: id)
    end

    def validate_not_used
      if store_credit_category_used?
        errors.add(:base, :cannot_destroy_if_used_in_store_credit)
        throw(:abort)
      end
    end

    def can_be_deleted?
      !store_credit_category_used?
    end

    class << self
      # The category store credit is issued under when a return, exchange or
      # claim pays the customer back internally.
      def default_refund_category(_options = {})
        Spree::StoreCreditCategory.first
      end

      # @deprecated use {.default_refund_category}
      def default_reimbursement_category(options = {})
        Spree::Deprecation.warn('Spree::StoreCreditCategory.default_reimbursement_category is deprecated and will be removed in Spree 6.1. Use .default_refund_category instead.')
        default_refund_category(options)
      end
    end
  end
end
