# frozen_string_literal: true

module Spree
  class GraphqlController < ActionController::API
    include Spree::Jwt::CurrentOrderConcern
    include Spree::Jwt::CurrentUserConcern

    rescue_from CanCan::AccessDenied, with: :access_denied

    def create
      query_string = params[:query]
      query_variables = ensure_hash(params[:variables])
      result = GraphqlSchema.execute(query_string, variables: query_variables, context: { spree_current_user: spree_current_user, spree_current_order:  find_spree_current_order})
      render json: result
    end

    private

    def access_denied(exception)
      render json: { errors: exception.message }, status: 403
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

    def spree_current_store
      @spree_current_store ||= ::Spree::Store.current(request.env['SERVER_NAME'])
    end
  end
end
