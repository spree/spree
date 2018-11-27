module Spree
  module Api
    module V2
      class BaseController < ActionController::API
        include CanCan::ControllerAdditions
        include Spree::Core::ControllerHelpers::StrongParameters
        rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
        rescue_from CanCan::AccessDenied, with: :access_denied

        private

        def render_serialized_payload(payload, status = 200)
          render json: payload, status: status
        rescue ArgumentError => exception
          render_error_payload(exception.message, 400)
        end

        def render_error_payload(error, status = 422)
          if error.is_a?(Struct)
            render json: { error: error.to_s, errors: error.to_h }, status: status
          elsif error.is_a?(String)
            render json: { error: error }, status: status
          end
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
            store: spree_current_store,
            user: spree_current_user,
            token: order_token,
            currency: current_currency
          )
        end

        def request_includes
          # if API user want's to receive only the bare-minimum
          # the API will return only the main resource without any included
          if params[:include]&.blank?
            []
          elsif params[:include].present?
            params[:include].split(',')
          end
        end

        def resource_includes
          (request_includes || default_resource_includes).map(&:intern)
        end

        # overwrite this method in your controllers to set JSON API default include value
        # https://jsonapi.org/format/#fetching-includes
        # eg.:
        # %w[images variants]
        # ['variant.images', 'line_items']
        def default_resource_includes
          []
        end

        def current_currency
          spree_current_store.default_currency || Spree::Config[:currency]
        end

        def record_not_found
          render_error_payload(I18n.t(:resource_not_found, scope: 'spree.api'), 404)
        end

        def access_denied(exception)
          render_error_payload(exception.message, 403)
        end
      end
    end
  end
end
