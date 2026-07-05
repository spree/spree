# Backward compatibility — all logic now lives in Spree::Asset.
# This class will be removed in Spree 6.0.
module Spree
  class Image < Asset
  end
end
