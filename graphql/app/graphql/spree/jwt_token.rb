module Spree
  class JwtToken
    AUTH_HEADER = 'X-Spree-JWT-Token'.freeze
    ORDER_HEADER = 'X-Spree-JWT-Order-Token'.freeze

    def self.create_for_user(user)
      time = (Time.current + Spree::Graphql::Config[:graphql_expiration])
      payload = { spree_user_id: user.id }
      payload[:exp] = time.to_i
      token = JWT.encode(payload, Spree::Graphql::Config[:graphql_secret_key])
      { token: token, exp: time.strftime("%m-%d-%Y %H:%M"), login: user.login }
    end

    def self.create_for_order(order)
      time = (Time.current + Spree::Graphql::Config[:graphql_expiration])
      payload = { spree_order_number: order.number }
      payload[:exp] = time.to_i
      token = JWT.encode(payload, Spree::Graphql::Config[:graphql_secret_key])
      { order_token: token, exp: time.strftime("%m-%d-%Y %H:%M") }
    end

    def self.decode(token)
      decoded = ::JWT.decode(token, Spree::Graphql::Config[:graphql_secret_key])[0]
      HashWithIndifferentAccess.new decoded
    end
  end
end
