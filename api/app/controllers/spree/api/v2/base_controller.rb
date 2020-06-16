module Spree
  module Api
    module V2
      class BaseController < ActionController::API
        include CanCan::ControllerAdditions
        include Spree::Core::ControllerHelpers::StrongParameters
        include Spree::Core::ControllerHelpers::Store
        rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
        rescue_from CanCan::AccessDenied, with: :access_denied
        rescue_from Spree::Core::GatewayError, with: :gateway_error

        def content_type
          Spree::Api::Config[:api_v2_content_type]
        end

        private

        def serialize_collection(collection)
          collection_serializer.new(
            collection,
            collection_options(collection)
          ).serializable_hash
        end

        def serialize_resource(resource)
          resource_serializer.new(
            resource,
            include: resource_includes,
            fields: sparse_fields
          ).serializable_hash
        end

        def paginated_collection
          collection_paginator.new(sorted_collection, params).call
        end

        def collection_paginator
          Spree::Api::Dependencies.storefront_collection_paginator.constantize
        end

        def render_serialized_payload(status = 200)
          render json: yield, status: status, content_type: content_type
        rescue ArgumentError => exception
          render_error_payload(exception.message, 400)
        end

        def render_error_payload(error, status = 422)
          if error.is_a?(Struct)
            render json: { error: error.to_s, errors: error.to_h }, status: status, content_type: content_type
          elsif error.is_a?(String)
            render json: { error: error }, status: status, content_type: content_type
          end
        end

        def spree_current_user
          @spree_current_user ||= Spree.user_class.find_by(id: doorkeeper_token.resource_owner_id) if doorkeeper_token
        end

        def spree_authorize!(action, subject, *args)
          authorize!(action, subject, *args)
        end

        def require_spree_current_user
          raise CanCan::AccessDenied if spree_current_user.nil?
        end

        # Needs to be overriden so that we use Spree's Ability rather than anyone else's.
        def current_ability
          @current_ability ||= Spree::Dependencies.ability_class.constantize.new(spree_current_user)
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

        def sparse_fields
          return unless params[:fields]&.respond_to?(:each)

          fields = {}
          params[:fields].
            select { |_, v| v.is_a?(String) }.
            each { |type, values| fields[type.intern] = values.split(',').map(&:intern) }
          fields.presence
        end

        def record_not_found
          render_error_payload(I18n.t(:resource_not_found, scope: 'spree.api'), 404)
        end

        def access_denied(exception)
          render_error_payload(exception.message, 403)
        end

        def gateway_error(exception)
          render_error_payload(exception.message)
        end
      end
    end
  end
end
