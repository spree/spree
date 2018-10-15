module Spree
  module Api
    module V2
      class BaseController < ActionController::API
        include CanCan::ControllerAdditions
        include Spree::Core::ControllerHelpers::StrongParameters
        rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

        private

        def render_serialized_payload(payload, status = 200)
          render json: payload, status: status
        rescue ArgumentError => exception
          render_error_payload(exception.message, 400)
        end

        def render_error_payload(error, status = 422)
          render json: { error: error }, status: status
        end

        def spree_current_store
          @spree_current_store ||= Spree::Store.current(request.env['SERVER_NAME'])
        end

        def spree_current_user
          @spree_current_user ||= Spree.user_class.find_by(id: doorkeeper_token.resource_owner_id) if doorkeeper_token
        end

        def spree_authorize!(action, subject, *args)
          authorize!(action, subject, *args)
        end

        # Needs to be overriden so that we use Spree's Ability rather than anyone else's.
        def current_ability
          @current_ability ||= Spree::Ability.new(spree_current_user)
        end

        def order_token
          request.headers['X-Spree-Order-Token'] || params[:order_token]
        end

        def spree_current_order
          @spree_current_order ||= find_spree_current_order
        end

        def find_spree_current_order
          Spree::Order::FindCurrent.new.execute(
            store:    spree_current_store,
            user:     spree_current_user,
            token:    order_token,
            currency: current_currency
          )
        end

        def request_includes
          params[:include].split(',').map(&:intern) if params[:include].present?
        end

        def current_currency
          spree_current_store.default_currency || Spree::Config[:currency]
        end

        def record_not_found(exception)
          render_error_payload(exception.message, 404)
        end
      end
    end
  end
end
