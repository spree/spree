module Spree
  module StorefrontApiHelper
    def spree_storefront_api_host
      if Spree::Frontend::Config[:storefront_api_host].present?
        Spree::Frontend::Config[:storefront_api_host]
      else
        "#{request.protocol}#{request.host_with_port}"
      end
    end
  end
end
