module Spree
  module Api
    module V3
      # Reads the `redirect_url` a storefront passes for an emailed link.
      #
      # The link carries a live token, so a page outside the store's allowed
      # origins would hand that token to whoever named the page. An address
      # that does not match is dropped rather than refused, so callers cannot
      # probe the allow-list through error responses.
      module AllowedRedirectUrl
        extend ActiveSupport::Concern

        private

        # @return [String, nil] the redirect URL when it matches one of the
        #   store's allowed origins
        def validated_redirect_url
          redirect_url = params[:redirect_url]
          return if redirect_url.blank?
          return unless current_store.allowed_origin?(redirect_url)

          redirect_url
        end
      end
    end
  end
end
