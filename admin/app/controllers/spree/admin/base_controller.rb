module Spree
  module Admin
    class BaseController < ApplicationController
      include Spree::Core::ControllerHelpers::Auth
      include Spree::Core::ControllerHelpers::Store
      include Spree::Core::ControllerHelpers::StrongParameters
      include Spree::Core::ControllerHelpers::Locale
      include Spree::Core::ControllerHelpers::Currency

      respond_to :html

      layout 'spree/admin'

      helper 'spree/base'
      helper 'spree/admin/navigation'
      helper 'spree/locale'
      helper 'spree/currency'

      before_action :authorize_admin

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

      def flash_message_for(object, event_sym)
        if object.is_a?(ActiveRecord::Relation)
          resource_desc = object.model.model_name.human.pluralize
        else
          resource_desc = object.class.model_name.human
          if (object.persisted? || object.destroyed?) && object.respond_to?(:name) && object.name.present? && !object.is_a?(Spree::Order)
            resource_desc += " \"#{object.name}\""
          end
        end

        Spree.t(event_sym, resource: resource_desc)
      end

      def config_locale
        I18n.default_locale
      end

      def current_timezone
        @current_timezone ||= current_store.timezone
      end

      def current_vendor
        nil
      end
    end
  end
end
