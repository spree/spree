module Spree
  module DigitalAssetHelper
    # Emails need an absolute link — the route helper only produces a path, and
    # the download endpoint lives on the backend rather than the storefront.
    #
    # @param digital_link [Spree::DigitalLink]
    # @return [String]
    def digital_link_download_url(digital_link)
      path = Spree::Core::Engine.routes.url_helpers.api_v3_store_digital_link_download_path(
        token: digital_link.token
      )

      URI.join(digital_link.order.store.formatted_url, path).to_s
    end
  end
end
