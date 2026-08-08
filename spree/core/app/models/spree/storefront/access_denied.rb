module Spree
  module Storefront
    # Raised when a storefront access check fails. Rendered by the API's
    # error handler as the same 403 payload CanCan::AccessDenied produces on
    # the admin side, so the two branches stay indistinguishable to clients.
    class AccessDenied < StandardError
      DEFAULT_MESSAGE = 'You are not authorized to access this page.'.freeze

      def initialize(message = nil)
        super(message || default_message)
      end

      private

      # CanCan's key first, so a host that translated admin denials gets the
      # same wording here.
      def default_message
        I18n.t(:default, scope: :unauthorized, default: DEFAULT_MESSAGE)
      end
    end
  end
end
