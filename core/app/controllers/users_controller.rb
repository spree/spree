class UsersController < Spree::BaseController
  resource_controller

  before_filter :require_no_user, :only => [:new, :create]
  before_filter :require_user, :only => [:show, :edit, :update]

  ssl_required :new, :create, :edit, :update, :show

  actions :all, :except => [:index, :destroy]

  create do
    flash nil
    success.wants.html { redirect_back_or_default products_path }
    success.wants.js { render :js => true.to_json }
    failure.wants.html { render :new }
    failure.wants.js { render :js => @user.errors.to_json }
  end

  show.before :show_before
  new_action.before :new_action_before

  def update
    @user = current_user
    if @user.update_attributes(params[:user])
      flash.notice = t("account_updated")
      redirect_to account_url
    else
      render :action => :edit
    end
  end

  private

    def object
      @object ||= current_user
    end

    def show_before
      @orders = @user.orders.checkout_complete
    end

    def new_action_before
      flash.now[:notice] = I18n.t(:please_create_user) unless admin_created?
    end

    def accurate_title
      I18n.t(:account)
    end
end
