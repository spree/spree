class UsersController < Spree::BaseController
  prepend_before_filter :load_object, :only => [:show, :edit, :update]
  prepend_before_filter :authorize_actions, :only => :new

  def show
    @orders = @user.orders.complete
  end

  def create
    @user = User.new(params[:user])
    if @user.save

      if current_order
        current_order.associate_user!(@user)
        session[:guest_token] = nil
      end

      redirect_back_or_default(root_url)
    else
      render 'new'
    end

  end

  def update
    if @user.update_attributes(params[:user])
      if params[:user][:password].present?
        # this logic needed b/c devise wants to log us out after password changes
        user = User.reset_password_by_token(params[:user])
        sign_in(@user, :event => :authentication)
      end
      flash.notice = I18n.t("account_updated")
      redirect_to account_url
    else
      render 'edit'
    end

  end

  private
    def load_object
      @user ||= current_user
      authorize! params[:action].to_sym, @user
    end

    def authorize_actions
      authorize! params[:action].to_sym, User
    end

    def accurate_title
      I18n.t(:account)
    end

end
