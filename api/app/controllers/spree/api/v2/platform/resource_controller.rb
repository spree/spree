module Spree
  module Api
    module V2
      module Platform
        class ResourceController < ::Spree::Api::V2::ResourceController
          READ_ACTIONS = %i[show index]
          WRITE_ACTIONS = %i[create update destroy]

          # doorkeeper scopes usage: https://github.com/doorkeeper-gem/doorkeeper/wiki/Using-Scopes
          before_action -> { doorkeeper_authorize! :read, :admin }, only: READ_ACTIONS
          before_action -> { doorkeeper_authorize! :write, :admin }, only: WRITE_ACTIONS

          # optional authorization if using a user token instead of app token
          before_action :authorize_spree_user, only: WRITE_ACTIONS

          # index and show acrtions are defined in Spree::Api::V2::ResourceController

          def create
            resource = model_class.new(permitted_resource_params)

            if resource.save
              render_serialized_payload(201) { serialize_resource(resource) }
            else
              render_error_payload(resource.errors)
            end
          end

          def update
            if resource.update(permitted_resource_params)
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

            model_class.includes(scope_includes)
          end

          # We're overwriting this method because the original one calls `dookreeper_authorize`
          # which breaks our application authorizations defined on top of this controller
          def spree_current_user
            return nil unless doorkeeper_token
            return nil if doorkeeper_token.resource_owner_id.nil?
            return @spree_current_user if @spree_current_user

            @spree_current_user ||= Spree.user_class.find_by(id: doorkeeper_token.resource_owner_id)
          end

          def access_denied(exception)
            access_denied_401(exception)
          end

          # if using a user oAuth token we need to check CanCanCan abilities
          # defined in https://github.com/spree/spree/blob/master/core/app/models/spree/ability.rb
          def authorize_spree_user
            return if spree_current_user.nil?

            if action_name == 'create'
              spree_authorize! :create, model_class
            else
              spree_authorize! action_name, resource
            end
          end

          def permitted_resource_params
            model_param_name = model_class.to_s.demodulize.underscore

            params.require(model_param_name).permit(Spree::PermittedAttributes.send("#{model_param_name}_attributes"))
          end
        end
      end
    end
  end
end
