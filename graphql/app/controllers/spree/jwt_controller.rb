# frozen_string_literal: true

module Spree
  class JwtController < ActionController::API
    include Spree::Jwt::CurrentOrderConcern
    include Spree::Jwt::CurrentUserConcern

    rescue_from JWT::DecodeError, with: :invalid_token

    def create
      if spree_current_user
        render json: ::Spree::JwtToken.create_for_user(spree_current_user), status: :ok
      else
        render json: { error: 'unauthorized' }, status: :unauthorized
      end
    end

    private

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
  end
end
