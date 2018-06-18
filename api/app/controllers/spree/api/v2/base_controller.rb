module Spree
  module Api
    module V2
      class BaseController < ActionController::API
        include CanCan::ControllerAdditions
        rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

        private

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
          Spree::Order::FindCurrent.new.execute(user: spree_current_user,
                                                store: spree_current_store,
                                                token: order_token,
                                                currency: params[:currency] || current_currency)
        end

        def current_currency
          spree_current_store.default_currency || Spree::Config[:currency]
        end

        def record_not_found(exception)
          render json: { error: exception.message }, status: 404
        end
      end
    end
  end
end
