module Spree
  module PasswordProtected
    extend ActiveSupport::Concern

    included do
      before_action :redirect_to_password
    end

    def redirect_to_password
      return if page_builder_enabled?
      return if session[:password_valid]
      return if turbo_frame_request?

      redirect_to password_path, status: 307 if respond_to?(:current_store) && current_store && current_store.prefers_password_protected?
    end
  end
end
