module Spree
  module NumberAsParam
    extend ActiveSupport::Concern

    included do
      Spree::Deprecation.warn(
        'Spree::NumberAsParam is deprecated and will be removed in Spree 6.0. ' \
        'Models now use Spree::PrefixedId with prefix_id column instead. ' \
        'This concern no longer provides any functionality and can be safely removed.'
      )
    end
  end
end
