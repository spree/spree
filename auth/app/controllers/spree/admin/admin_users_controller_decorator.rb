require File.expand_path('../../base_controller_decorator', __FILE__)
Spree::Admin::UsersController.class_eval do
  rescue_from Spree::User::DestroyWithOrdersError, :with => :user_destroy_with_orders_error

  update.after :sign_in_if_change_own_password

  before_filter :load_roles, :only => [:edit, :new, :update, :create]

  private

    def sign_in_if_change_own_password
      if current_user == @user && @user.password.present?
        sign_in(@user, :event => :authentication, :bypass => true)
      end
    end

    def load_roles
      @roles = Spree::Role.scoped
    end

    # subvert role_ids mass assignment protection
    def load_resource_instance
      role_ids = params[:user].delete(:role_ids) if params[:user] && params[:user][:role_ids]
      super.tap { |user| user.role_ids = role_ids if role_ids }
    end
end

