# @deprecated This module is now a no-op. All logic has been moved to Spree::Asset.
# Will be removed in Spree 6.0.
module Spree
  class Image < Asset
    module Configuration
      module ActiveStorage
        extend ActiveSupport::Concern
      end
    end
  end
end
