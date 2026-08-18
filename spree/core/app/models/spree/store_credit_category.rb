module Spree
  # @deprecated Removed in Spree 6.1 together with its table. Store credit no
  #   longer carries a category — the reason a credit exists lives in
  #   {Spree::StoreCredit#originator} (the return, exchange, claim or gift
  #   card that issued it) and in its free-text +memo+. The class stays only
  #   so extensions referencing the constant fail loudly rather than with a
  #   NameError; nothing in Spree reads or writes these rows any more.
  class StoreCreditCategory < Spree.base_class
    has_prefix_id :sccat

    GIFT_CARD_CATEGORY_NAME = 'Gift Card'.freeze
    DEFAULT_NON_EXPIRING_TYPES = [GIFT_CARD_CATEGORY_NAME]

    after_initialize do
      Spree::Deprecation.warn('Spree::StoreCreditCategory is deprecated and will be removed in Spree 6.1. ' \
                              'Store credits no longer carry a category — use StoreCredit#originator and #memo instead.')
    end

    class << self
      # @deprecated Removed in Spree 6.1. Refund workflows no longer set a
      #   category on the store credit they issue.
      def default_refund_category(_options = {})
        Spree::Deprecation.warn('Spree::StoreCreditCategory.default_refund_category is deprecated and will be removed in Spree 6.1. ' \
                                'Store credits no longer carry a category.')
        first
      end

      # @deprecated use {.default_refund_category}
      def default_reimbursement_category(options = {})
        Spree::Deprecation.warn('Spree::StoreCreditCategory.default_reimbursement_category is deprecated and will be removed in Spree 6.1. ' \
                                'Store credits no longer carry a category.')
        default_refund_category(options)
      end
    end
  end
end
