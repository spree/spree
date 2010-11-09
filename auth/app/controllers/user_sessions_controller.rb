class UserSessionsController < Devise::SessionsController
  include SpreeBase
  helper :users, 'spree/base'

  include Spree::CurrentOrder
  include Spree::AuthUser

  after_filter :associate_user, :only => :create

  ssl_required :new, :create, :destroy, :update
  ssl_allowed :login_bar

  # GET /resource/sign_in
  def new
    super
  end

  def create
    resource = warden.authenticate!(:scope => resource_name, :recall => "new")
    set_flash_message :notice, :signed_in
    if user_signed_in?

      respond_to do |format|
        format.html {
          flash[:notice] = t("logged_in_succesfully") unless session[:return_to]
          redirect_back_or_default(products_path)
        }
        format.js {
          user = resource.record
          render :json => {:ship_address => user.ship_address, :bill_address => user.bill_address}.to_json
        }
      end
    else
      respond_to do |format|
        format.html {
          flash.now[:error] = t("login_failed")
          render :action => :new
        }
        format.js { render :json => false }
        format.json {render :text => 'access_denied', :status => 401}
      end
    end
    redirect_back_or_default(products_path) unless performed?
  end

  def destroy
    session.clear
    super
  end

  def nav_bar
    render :partial => "shared/nav_bar"
  end

  private

  def associate_user
    return unless current_user and current_order
    current_order.associate_user!(current_user)
    session[:guest_token] = nil
  end

  def accurate_title
    I18n.t(:log_in)
  end

end