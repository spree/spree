module Spree
  module DigitalAssetHelper
    # Emails need an absolute link — the route helper only produces a path, and
    # the download endpoint lives on the backend rather than the storefront.
    #
    # The host is passed in rather than resolved per link: every link in one
    # email belongs to the same order, so its store is already known.
    #
    # @param digital_link [Spree::DigitalLink]
    # @param host [String] the backend's own URL
    # @return [String]
    def digital_link_download_url(digital_link, host)
      Spree::Api::DigitalLinkUrls.download_url(digital_link, host)
    end
  end
end
