module Spree
  module Api
    # The one place that knows how a finished export is addressed. Mirrors
    # DigitalLinkUrls: the route only exists in this gem, while the email that
    # needs it absolute lives in another.
    module DataRequestUrls
      module_function

      # @param data_request [Spree::DataRequest]
      # @return [String] path relative to the API host
      def download_path(data_request)
        Spree::Core::Engine.routes.url_helpers.api_v3_store_data_request_download_path(
          token: data_request.download_token
        )
      end

      # @param data_request [Spree::DataRequest]
      # @param host [String] the backend's own URL
      # @return [String] absolute URL, for emails and anything else off-request
      def download_url(data_request, host)
        URI.join(host, download_path(data_request)).to_s
      end
    end
  end
end
