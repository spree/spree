module Spree
  # @deprecated Removed in Spree 6.1 together with its table. Nothing in Spree
  #   ever created a store credit type, so the +priority+ it was meant to
  #   provide never drove redemption order; store credits are now spent
  #   oldest first ({Spree::StoreCredit.oldest_first}). The class stays only so
  #   extensions referencing the constant fail loudly rather than with a
  #   NameError.
  class StoreCreditType < Spree.base_class
    has_prefix_id :sctype

    DEFAULT_TYPE_NAME = 'Expiring'.freeze

    after_initialize do
      Spree::Deprecation.warn('Spree::StoreCreditType is deprecated and will be removed in Spree 6.1. ' \
                              'Store credits are spent oldest first — see Spree::StoreCredit.oldest_first.')
    end
  end
end
