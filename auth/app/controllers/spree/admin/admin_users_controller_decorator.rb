require File.expand_path('../../base_controller_decorator', __FILE__)
Spree::Admin::UsersController.class_eval do
  rescue_from Spree::User::DestroyWithOrdersError, :with => :user_destroy_with_orders_error

  update.after :sign_in_if_change_own_password

  before_filter :load_roles, :only => [:edit, :new, :update, :create]

  def create
    if params[:user]
      roles = params[:user].delete("role_ids")
    end

    @user = Spree::User.new(params[:user])

    invoke_callbacks(:create, :before)

    if @user.save
      invoke_callbacks(:create, :after)

      if roles
        @user.roles = roles.reject(&:blank?).collect{|r| Spree::Role.find(r)}
      end

      flash.now[:notice] = t(:created_successfully)
      render :edit
    else
      invoke_callbacks(:create, :fails)
      render :new
    end
  end

  def update
    if params[:user]
      roles = params[:user].delete("role_ids")
    end

    invoke_callbacks(:update, :before)

    if @user.update_attributes(params[:user])
      invoke_callbacks(:update, :after)

      if roles
        @user.roles = roles.reject(&:blank?).collect{|r| Spree::Role.find(r)}
      end

      if params[:user][:password].present?
        # this logic needed b/c devise wants to log us out after password changes
        user = Spree::User.reset_password_by_token(params[:user])
        sign_in(@user, :event => :authentication, :bypass => !Spree::Auth::Config[:signout_after_password_change])
      end
      flash.now[:notice] = t(:account_updated)
      render :edit
    else
      invoke_callbacks(:update, :fails)
      render :edit
    end
  end

  private

    def sign_in_if_change_own_password
      if current_user == @user && @user.password.present?
        sign_in(@user, :event => :authentication, :bypass => true)
      end
    end

    def load_roles
      @roles = Spree::Role.scoped
    end
end

