module Spree
  module Api
    module V1
      class BaseController < ApplicationController
        include Spree::Core::ControllerHelpers::Auth

        respond_to :json

        attr_accessor :current_api_user

        before_filter :set_content_type
        before_filter :check_for_user_or_api_key, :if => :requires_authentication?
        before_filter :authenticate_user
        after_filter  :set_jsonp_format

        rescue_from CanCan::AccessDenied, :with => :unauthorized
        rescue_from ActiveRecord::RecordNotFound, :with => :not_found

        helper Spree::Api::ApiHelpers

        def set_jsonp_format
          if params[:callback] && request.get?
            self.response_body = "#{params[:callback]}(#{self.response_body})"
            headers["Content-Type"] = 'application/javascript'
          end
        end

        def map_nested_attributes_keys(klass, attributes)
          nested_keys = klass.nested_attributes_options.keys
          attributes.inject({}) do |h, (k,v)|
            key = nested_keys.include?(k.to_sym) ? "#{k}_attributes" : k
            h[key] = v
            h
          end.with_indifferent_access
        end

        private

        def set_content_type
          content_type = case params[:format]
          when "json"
            "application/json"
          when "xml"
            "text/xml"
          end
          headers["Content-Type"] = content_type
        end

        def check_for_user_or_api_key
          # User is already authenticated with Spree, make request this way instead.
          return true if @current_api_user = try_spree_current_user

          if api_key.blank?
            render "spree/api/v1/errors/must_specify_api_key", :status => 401 and return
          end
        end

        def authenticate_user
          if requires_authentication? || api_key.present?
            unless @current_api_user ||= Spree.user_class.find_by_spree_api_key(api_key)
              render "spree/api/v1/errors/invalid_api_key", :status => 401 and return
            end
          else
            # Effectively, an anonymous user
            @current_api_user = Spree.user_class.new
          end
        end

        def unauthorized
          render "spree/api/v1/errors/unauthorized", :status => 401 and return
        end

        def requires_authentication?
          Spree::Api::Config[:requires_authentication]
        end

        def not_found
          render "spree/api/v1/errors/not_found", :status => 404 and return
        end

        def current_ability
          Spree::Ability.new(current_api_user)
        end

        def invalid_resource!(resource)
          @resource = resource
          render "spree/api/v1/errors/invalid_resource", :status => 422
        end

        def api_key
          request.headers["X-Spree-Token"] || params[:token]
        end
        helper_method :api_key

        def find_product(id)
          begin
            product_scope.find_by_permalink!(id.to_s)
          rescue ActiveRecord::RecordNotFound
            product_scope.find(id)
          end
        end

        def product_scope
          if current_api_user.has_spree_role?("admin")
            scope = Product
            unless params[:show_deleted]
              scope = scope.not_deleted
            end
          else
            scope = Product.active
          end

          scope.includes(:master)
        end

      end
    end
  end
end

