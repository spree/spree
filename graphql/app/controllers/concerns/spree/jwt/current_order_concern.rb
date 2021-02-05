module Spree
  module Jwt
    module CurrentOrderConcern
      def find_spree_current_order
        @spree_current_order ||= begin
          header = request.headers[::Spree::JwtToken::ORDER_HEADER]
          return nil unless header
          payload = ::Spree::JwtToken.decode(header)
          ::Spree::Order.find_by(number: payload[:spree_order_number])
        end
      end
    end
  end
end
