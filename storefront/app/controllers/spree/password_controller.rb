module Spree
  class PasswordController < StoreController
    layout 'spree/password'

    skip_before_action :redirect_to_password

    def show
      @current_page = current_theme.pages.find_by(type: 'Spree::Pages::Password')
    end

    def check
      if params[:password] == current_store.storefront_password
        session[:password_valid] = true
        redirect_to root_path
      else
        flash[:error] = 'Incorrect password. Please try again.'
        redirect_to password_path
      end
    end
  end
end
