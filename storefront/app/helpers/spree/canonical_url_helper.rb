module Spree
  module CanonicalUrlHelper
    # Generates a canonical link tag for the current page
    #
    # @param host [String] The host/domain to use (defaults to current store's domain)
    # @return [ActiveSupport::SafeBuffer] The canonical link tag HTML
    def canonical_tag(host = nil)
      tag.link(href: canonical_href(host), rel: :canonical)
    end

    # Returns the full canonical URL for the current request
    #
    # @param host [String] The host/domain to use (defaults to request host)
    # @return [String] The full canonical URL
    def canonical_href(host = nil)
      host ||= request.host
      "#{request.protocol}#{host}#{canonical_path}"
    end

    # Returns the canonical path for the current request (without query parameters)
    #
    # @return [String] The canonical path
    def canonical_path
      request.path.presence || '/'
    end
  end
end
