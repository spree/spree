module Spree
  module Api
    module V2
      class BaseController < ActionController::API
        include ActiveStorage::SetCurrent
        include CanCan::ControllerAdditions
        include Spree::Core::ControllerHelpers::StrongParameters
        include Spree::Core::ControllerHelpers::Store
        include Spree::Core::ControllerHelpers::Locale
        include Spree::Core::ControllerHelpers::Currency

        rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
        rescue_from CanCan::AccessDenied, with: :access_denied
        rescue_from Doorkeeper::Errors::DoorkeeperError, with: :access_denied_401
        rescue_from Spree::Core::GatewayError, with: :gateway_error
        rescue_from ActionController::ParameterMissing, with: :error_during_processing
        if defined?(JSONAPI::Serializer::UnsupportedIncludeError)
          rescue_from JSONAPI::Serializer::UnsupportedIncludeError, with: :error_during_processing
        end
        rescue_from ArgumentError, with: :error_during_processing
        rescue_from ActionDispatch::Http::Parameters::ParseError, with: :error_during_processing

        # Returns the content type for the API
        # @return [String] The content type, eg 'application/vnd.api+json'
        def content_type
          Spree::Api::Config[:api_v2_content_type]
        end

        protected

        def serialize_collection(collection)
          collection_serializer.new(
            collection,
            collection_options(collection).merge(params: serializer_params)
          ).serializable_hash
        end

        def serialize_resource(resource)
          resource_serializer.new(
            resource,
            params: serializer_params,
            include: resource_includes,
            fields: sparse_fields
          ).serializable_hash
        end

        # Returns a paginated collection
        # @return [Array] The paginated collection
        def paginated_collection
          @paginated_collection ||= collection_paginator.new(sorted_collection, params).call
        end

        # Returns the collection paginator
        # @return [Class] The collection paginator class, default is Spree::Shared::Paginate
        def collection_paginator
          Spree.api.storefront_collection_paginator
        end

        # Renders a serialized payload with the given status code
        # @param status [Integer] HTTP status code to return, eg 200, 201, 204
        # @yield [Hash] The serialized data to render
        def render_serialized_payload(status = 200)
          render json: yield, status: status, content_type: content_type
        end

        # Renders a serialized error payload with the given status code
        # @param status [Integer] HTTP status code to return
        # @yield [Hash] The serialized data to render
        def render_error_payload(error, status = 422)
          json = if error.is_a?(ActiveModel::Errors)
                   { error: error.full_messages.to_sentence, errors: error.messages }
                 elsif error.is_a?(Struct)
                   { error: error.to_s, errors: error.to_h }
                 else
                   { error: error }
                 end

          render json: json, status: status, content_type: content_type
        end

        # Renders a serialized result payload with the given status code
        # @param result [Object] The result to render
        # @param ok_status [Integer] HTTP status code to return if the result is successful, eg 200, 201, 204
        def render_result(result, ok_status = 200)
          if result.success?
            render_serialized_payload(ok_status) { serialize_resource(result.value) }
          else
            render_error_payload(result.error)
          end
        end

        # Returns the current Spree user
        # @return [Spree.user_class] The current Spree user
        def spree_current_user
          return nil unless doorkeeper_token
          return @spree_current_user if defined?(@spree_current_user)

          @spree_current_user ||= ActiveRecord::Base.connected_to(role: :writing) do
            doorkeeper_authorize!
            doorkeeper_token.resource_owner
          end
        end

        alias try_spree_current_user spree_current_user  # for compatibility with spree_legacy_frontend

        # Authorizes the current Spree user for the given action and subject
        # @param action [Symbol] The action to authorize
        # @param subject [Object] The subject to authorize
        # @param args [Array] Additional arguments to pass to the authorize! method
        # @return [void]
        def spree_authorize!(action, subject, *args)
          authorize!(action, subject, *args)
        end

        # Raises an AccessDenied error if the current Spree user is nil
        # @raise [CanCan::AccessDenied] If the current Spree user is nil
        def require_spree_current_user
          raise CanCan::AccessDenied if spree_current_user.nil?
        end

        # Needs to be overridden so that we use Spree's Ability rather than anyone else's.
        def current_ability
          @current_ability ||= Spree.ability_class.new(spree_current_user, ability_options)
        end

        # this method can be extended in extensions or developer applications
        # @return [Hash] The ability options
        def ability_options
          { store: current_store }
        end

        # Returns the requested includes
        # @return [Array] The requested includes
        def request_includes
          # if API user wants to receive only the bare-minimum
          # the API will return only the main resource without any included
          if params[:include]&.blank?
            []
          elsif params[:include].present?
            params[:include].split(',')
          end
        end

        # Returns the resource includes, useful to avoid N+1 queries
        # @return [Array] The resource includes, eg [:images, :variants]
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

        # Returns the JSON API sparse fields
        # @return [Hash] The sparse fields, eg { product: [:name, :description] }
        def sparse_fields
          return unless params[:fields]&.respond_to?(:each)

          fields = {}
          params[:fields].
            select { |_, v| v.is_a?(String) }.
            each { |type, values| fields[type.intern] = values.split(',').map(&:intern) }
          fields.presence
        end

        # Returns the serializer global params
        # all of these params are passed down to the serializer
        # @return [Hash] The serializer params
        def serializer_params
          {
            currency: current_currency,
            locale: current_locale,
            price_options: current_price_options,
            store: current_store,
            user: spree_current_user,
            image_transformation: params[:image_transformation],
            taxon_image_transformation: params[:taxon_image_transformation]
          }
        end

        # Renders a 404 error payload
        # @param exception [Exception] The exception to render
        # @return [void]
        def record_not_found(exception)
          Rails.error.report(exception, context: { user_id: spree_current_user&.id }, source: 'spree.api')

          render_error_payload(I18n.t(:resource_not_found, scope: 'spree.api'), 404)
        end

        # Renders a 403 error payload
        # @param exception [Exception] The exception to render
        # @return [void]
        def access_denied(exception)
          Rails.error.report(exception, context: { user_id: spree_current_user&.id }, source: 'spree.api')

          render_error_payload(exception.message, 403)
        end

        # Renders a 401 error payload
        # @param exception [Exception] The exception to render
        # @return [void]
        def access_denied_401(exception)
          render_error_payload(exception.message, 401)
        end

        # Renders a 500 error payload when a payment gateway error occurs
        # @param exception [Exception] The exception to render
        # @return [void]
        def gateway_error(exception)
          Rails.error.report(exception, context: { user_id: spree_current_user&.id }, source: 'spree.api')

          render_error_payload(exception.message)
        end

        # Renders a 400 error payload when an error occurs during parameter parsing
        # @param exception [Exception] The exception to render
        # @return [void]
        def error_during_processing(exception)
          Rails.error.report(exception, context: { user_id: spree_current_user&.id }, source: 'spree.api')

          message = exception.respond_to?(:original_message) ? exception.original_message : exception.message

          render_error_payload(message, 400)
        end
      end
    end
  end
end
