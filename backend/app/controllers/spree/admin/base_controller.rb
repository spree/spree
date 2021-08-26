module Spree
  module Admin
    class BaseController < ApplicationController
      include Spree::Core::ControllerHelpers::Auth
      include Spree::Core::ControllerHelpers::Search
      include Spree::Core::ControllerHelpers::Store
      include Spree::Core::ControllerHelpers::StrongParameters
      include Spree::Core::ControllerHelpers::Locale
      include Spree::Core::ControllerHelpers::Currency

      respond_to :html

      helper 'spree/base'
      helper 'spree/admin/navigation'
      helper 'spree/locale'
      helper 'spree/currency'
      layout 'spree/layouts/admin'

      before_action :authorize_admin
      before_action :generate_admin_api_key
      before_action :load_stores

      helper_method :admin_oauth_token

      protected

      def action
        params[:action].to_sym
      end

      def authorize_admin
        record = if respond_to?(:model_class, true) && model_class
                   model_class
                 else
                   controller_name.to_sym
                 end
        authorize! :admin, record
        authorize! action, record
      end

      def redirect_unauthorized_access
        if try_spree_current_user
          flash[:error] = Spree.t(:authorization_failure)
          redirect_to spree.admin_forbidden_path
        else
          store_location
          if defined?(spree.admin_login_path)
            redirect_to spree.admin_login_path
          elsif respond_to?(:spree_login_path)
            redirect_to spree_login_path
          elsif spree.respond_to?(:root_path)
            redirect_to spree.root_path
          else
            redirect_to main_app.respond_to?(:root_path) ? main_app.root_path : '/'
          end
        end
      end

      # Need to generate an API key for a user due to some backend actions
      # requiring authentication to the Spree API
      def generate_admin_api_key
        if (user = try_spree_current_user) && user.spree_api_key.blank?
          user.generate_spree_api_key!
        end
      end

      def flash_message_for(object, event_sym)
        resource_desc  = object.class.model_name.human
        resource_desc += " \"#{object.name}\"" if (object.persisted? || object.destroyed?) && object.respond_to?(:name) && object.name.present? && !object.is_a?(Spree::Order)
        Spree.t(event_sym, resource: resource_desc)
      end

      def render_js_for_destroy
        render partial: '/spree/admin/shared/destroy'
      end

      def config_locale
        Spree::Backend::Config[:locale]
      end

      def stores_scope
        Spree::Store.accessible_by(current_ability, :show)
      end

      def load_stores
        @stores = stores_scope.order(default: :desc)
      end

      def can_not_transition_without_customer_info
        unless @order.billing_address.present?
          flash[:notice] = Spree.t(:fill_in_customer_info)
          redirect_to spree.edit_admin_order_customer_url(@order)
        end
      end

      def admin_oauth_application
        @admin_oauth_application ||= begin
          Doorkeeper::Application.find_or_create_by!(name: 'Admin Panel', scopes: 'admin', redirect_uri: '')
        end
      end

      # FIXME: auto-expire this token
      def admin_oauth_token
        user = try_spree_current_user
        return unless user

        @admin_oauth_token ||= begin
          Doorkeeper::AccessToken.active_for(user).where(application_id: admin_oauth_application.id).last ||
            Doorkeeper::AccessToken.create!(
              resource_owner_id: user.id,
              application_id: admin_oauth_application.id,
              scopes: admin_oauth_application.scopes
            )
        end.token
      end
    end
  end
end
