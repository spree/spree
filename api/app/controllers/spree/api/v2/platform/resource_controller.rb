module Spree
  module Api
    module V2
      module Platform
        class ResourceController < ::Spree::Api::V2::ResourceController
          # doorkeeper scopes usage: https://github.com/doorkeeper-gem/doorkeeper/wiki/Using-Scopes
          before_action -> { doorkeeper_authorize! :read, :admin }
          before_action -> { doorkeeper_authorize! :write, :admin }, if: :write_request?

          # optional authorization if using a user token instead of app token
          before_action :authorize_spree_user

          # index and show acrtions are defined in Spree::Api::V2::ResourceController

          def create
            resource = model_class.new(permitted_resource_params)

            ensure_current_store(resource)

            if resource.save
              render_serialized_payload(201) { serialize_resource(resource) }
            else
              render_error_payload(resource.errors)
            end
          end

          def update
            if resource.update(permitted_resource_params)
              ensure_current_store(resource)
              render_serialized_payload { serialize_resource(resource) }
            else
              render_error_payload(resource.errors)
            end
          end

          def destroy
            if resource.destroy
              head 204
            else
              render_error_payload(resource.errors)
            end
          end

          protected

          def resource_serializer
            "Spree::Api::V2::Platform::#{model_class.to_s.demodulize}Serializer".constantize
          end

          def collection_serializer
            resource_serializer
          end

          # overwiting to utilize ransack gem for filtering
          # https://github.com/activerecord-hackery/ransack#search-matchers
          def collection
            @collection ||= scope.ransack(params[:filter]).result
          end

          # overwriting to skip cancancan check if API is consumed by an application
          def scope
            return super if spree_current_user.present?

            super(skip_cancancan: true)
          end

          # We're overwriting this method because the original one calls `dookreeper_authorize`
          # which breaks our application authorizations defined on top of this controller
          def spree_current_user
            return nil unless doorkeeper_token
            return nil if doorkeeper_token.resource_owner_id.nil?
            return @spree_current_user if @spree_current_user

            @spree_current_user ||= doorkeeper_token.resource_owner
          end

          def access_denied(exception)
            access_denied_401(exception)
          end

          # if using a user oAuth token we need to check CanCanCan abilities
          # defined in https://github.com/spree/spree/blob/master/core/app/models/spree/ability.rb
          def authorize_spree_user
            return if spree_current_user.nil?

            case action_name
            when 'create'
              spree_authorize! :create, model_class
            when 'destroy'
              spree_authorize! :destroy, resource
            when 'index'
              spree_authorize! :read, model_class
            when 'show'
              spree_authorize! :read, resource
            else
              spree_authorize! :update, resource
            end
          end

          def model_param_name
            model_class.to_s.demodulize.underscore
          end

          def spree_permitted_attributes
            model_class.json_api_permitted_attributes
          end

          def permitted_resource_params
            params.require(model_param_name).permit(spree_permitted_attributes)
          end

          def allowed_sort_attributes
            (super << spree_permitted_attributes).uniq.compact
          end

          def write_request?
            %w[put patch post delete].include?(request.request_method.downcase)
          end
        end
      end
    end
  end
end
