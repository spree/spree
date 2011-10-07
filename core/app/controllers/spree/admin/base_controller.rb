module Spree
  module Admin
    class BaseController < Spree::BaseController
      ssl_required

      helper 'spree/search'
      helper 'spree/admin/navigation'
      layout 'spree/admin'

      protected
  
      def flash_message_for(object, event_sym)
        resource_desc  = object.class.model_name.human
        resource_desc += " \"#{object.name}\"" if object.respond_to?(:name)
        I18n.t(event_sym, :resource => resource_desc)  
      end
  
      def render_js_for_destroy
        render :partial => "spree/admin/shared/destroy"
      end
  
      # Index request for JSON needs to pass a CSRF token in order to prevent JSON Hijacking
      def check_json_authenticity
        return unless request.format.js? or request.format.json?
        return unless protect_against_forgery?
        auth_token = params[request_forgery_protection_token]
        unless (auth_token and form_authenticity_token == URI.unescape(auth_token))
          raise(ActionController::InvalidAuthenticityToken)
        end
      end

      # def require_object_editable_by_current_user
      #   return access_denied unless object.editable_by?(current_user)
      #   true
      # end
    end
  end
end