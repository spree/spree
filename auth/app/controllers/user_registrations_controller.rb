class UserRegistrationsController < Devise::RegistrationsController
  include SpreeBase
  helper :users, 'spree/base'

  before_filter :check_permissions, :only => [:edit, :update]
  skip_before_filter :require_no_authentication

  # GET /resource/sign_up
  def new
    super
  end

  # POST /resource/sign_up
  def create
    @user = build_resource(params[:user])
    logger.debug(@user)
    if resource.save
      set_flash_message(:notice, :signed_up)
      sign_in_and_redirect(:user, @user)
    else
      clean_up_passwords(resource)
      render_with_scope(:new)
    end
  end

  # GET /resource/edit
  def edit
    super
  end

  # PUT /resource
  def update
    super
  end

  # DELETE /resource
  def destroy
    super
  end

  # GET /resource/cancel
  # Forces the session data which is usually expired after sign
  # in to be expired now. This is useful if the user wants to
  # cancel oauth signing in/up in the middle of the process,
  # removing all OAuth session data.
  def cancel
    super
  end

  protected

  def check_permissions
    authorize!(:create, resource)
  end

end