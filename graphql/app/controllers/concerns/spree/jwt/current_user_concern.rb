module Spree
  module Jwt
    module CurrentUserConcern
      def spree_current_user
        @spree_current_user ||= begin
          if params[:email].present? && params[:password].present?
            user = ::Spree.user_class.find(email: params[:email])
            if user.respond_to?(:valid_password?) && user.valid_password?(params[:password])
              return user
            else
              return nil
            end
          end
          header = request.headers[::Spree::JwtToken::AUTH_HEADER]
          return ::Spree.user_class.new unless header

          token = header.split(' ').last
          payload = ::Spree::JwtToken.decode(token)
          ::Spree.user_class.find_by_id(payload[:spree_user_id])
        end
      end
    end
  end
end
