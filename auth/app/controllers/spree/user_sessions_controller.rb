class Spree::UserSessionsController < Devise::SessionsController
  include Spree::Core::ControllerHelpers
  helper 'spree/users', 'spree/base'

  include Spree::Core::CurrentOrder

  after_filter :associate_user, :only => :create

  ssl_required :new, :create, :destroy, :update
  ssl_allowed :login_bar

  def create
    authenticate_user!

    if user_signed_in?
      respond_to do |format|
        format.html {
          flash.notice = t(:logged_in_succesfully)
          redirect_back_or_default(products_path)
        }
        format.js {
          user = resource.record
          render :json => {:ship_address => user.ship_address, :bill_address => user.bill_address}.to_json
        }
      end
    else
      flash.now[:error] = t('devise.failure.invalid')
      render :new
    end
  end

  def nav_bar
    render :partial => 'spree/shared/nav_bar'
  end

  private
    def accurate_title
      t(:login)
    end
end
