module Spree
  module Api
    # The one place that knows how a download link is addressed. Both consumers
    # live in different gems — the store serializer emits the path, the email
    # needs it absolute — and the route only exists here, in the gem that draws
    # it, so neither the core model nor the emails gem can own this.
    module DigitalLinkUrls
      module_function

      # @param digital_link [Spree::DigitalLink]
      # @return [String] path relative to the API host
      def download_path(digital_link)
        Spree::Core::Engine.routes.url_helpers.api_v3_store_digital_link_download_path(
          token: digital_link.token
        )
      end

      # @param digital_link [Spree::DigitalLink]
      # @param host [String] the backend's own URL
      # @return [String] absolute URL, for emails and anything else off-request
      def download_url(digital_link, host)
        URI.join(host, download_path(digital_link)).to_s
      end
    end
  end
end
