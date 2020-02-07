# frozen_string_literal: true

module Spree
  module Graphql
    class GraphqlController < ActionController::API
      rescue_from CanCan::AccessDenied, with: :access_denied
      rescue_from JWT::DecodeError, with: :invalid_token

      def create
        query_string = params[:query]
        query_variables = ensure_hash(params[:variables])
        result = GraphqlSchema.execute(query_string, variables: query_variables, context: { spree_current_user: spree_current_user, spree_current_order:  find_spree_current_order})
        render json: result
      end

      def login
        if spree_current_user
          render json: ::Spree::JwtToken.create_for_user(spree_current_user), status: :ok
        else
          render json: { error: 'unauthorized' }, status: :unauthorized
        end
      end

      private

      def access_denied(exception)
        render json: { errors: exception.message }, status: 403
      end

      def invalid_token(exception)
        render json: { errors: exception.message }, status: :unauthorized
      end

      def ensure_hash(query_variables)
        if query_variables.blank?
          {}
        elsif query_variables.is_a?(String)
          JSON.parse(query_variables)
        else
          query_variables
        end
      end

      def find_spree_current_order
        @spree_current_order ||= begin
          header = request.headers[::Spree::JwtToken::ORDER_HEADER]
          return nil unless header
          payload = ::Spree::JwtToken.decode(header)
          ::Spree::Order.find_by(number: payload[:spree_order_number])
        end
      end

      def spree_current_store
        @spree_current_store ||= ::Spree::Store.current(request.env['SERVER_NAME'])
      end

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
