module Spree
  module Admin
    class BaseController < Spree::BaseController
      include Spree::Admin::BreadcrumbConcern

      layout :choose_layout
      default_form_builder Spree::Admin::FormBuilder

      helper 'spree/base'
      helper 'spree/admin/navigation'
      helper 'spree/locale'
      helper 'spree/currency'
      helper 'spree/addresses'
      helper 'spree/integrations'

      before_action :authorize_admin
      after_action :set_return_to, only: [:index]

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
          redirect_back(fallback_location: spree.admin_forbidden_path)
        else
          store_location
          try_to_redirect_to_login_path
        end
      end

      def try_to_redirect_to_login_path
        if defined?(spree_admin_login_path)
          redirect_to spree_admin_login_path, allow_other_host: true
        elsif respond_to?(:spree_login_path)
          redirect_to spree_login_path, allow_other_host: true
        elsif spree.respond_to?(:root_path)
          redirect_to spree.root_path, allow_other_host: true
        else
          redirect_to main_app.respond_to?(:root_path) ? main_app.root_path : '/'
        end
      end

      def try_spree_current_user
        if Spree.admin_user_class && Spree.admin_user_class != Spree.user_class
          send("current_#{Spree.admin_user_class.model_name.singular_route_key}")
        else
          # use Spree::Core::ControllerHelpers::Auth#try_spree_current_user
          super
        end
      end

      def store_location_session_key
        "#{Spree.admin_user_class.model_name.singular_route_key.to_sym}_return_to"
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
        @current_timezone ||= current_store.preferred_timezone
      end

      def current_currency
        @current_currency ||= if params[:currency].present? && supported_currency?(params[:currency])
                                params[:currency]
                              elsif current_store.present?
                                current_store.default_currency
                              else
                                Spree::Store.default.default_currency
                              end&.upcase
      end

      def current_vendor
        nil
      end

      def set_return_to
        return unless defined?(model_class)
        return unless request.format.html?

        clear_return_to

        session_key = "#{model_class.to_s.demodulize.pluralize.downcase}_return_to".to_sym
        session[session_key] = "#{request.path}?#{request.query_string}"
      rescue ActionDispatch::Cookies::CookieOverflow
        clear_return_to
      end

      def clear_return_to
        session.keys.find_all { |k| k.ends_with?('_return_to') }.each do |k|
          session.delete(k)
        end
      end

      def remove_assets(attachment_types, object: nil)
        attachment_types.each do |attachment_type|
          remove_param = "remove_#{attachment_type}"
          if params[remove_param] == '1'
            object ||= attachment_type == 'asset' ? @page_section : @object
            attachment = object.public_send(attachment_type)
            if attachment.attached?
              attachment.detach
              attachment.purge_later
            end
          end
        end
      end

      def choose_layout
        return 'turbo_rails/frame' if turbo_frame_request?

        'spree/admin'
      end

      def parse_date_param(date_string)
        return if date_string.blank?

        date_string.to_date&.in_time_zone(current_timezone)
      end
    end
  end
end
