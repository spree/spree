class UsersController < Spree::BaseController
  resource_controller

  ssl_required :new, :create, :edit, :update, :show

  actions :all, :except => [:index, :destroy]

  show.before do
    @orders = @user.orders.complete
  end

  create.after do
    associate_user
  end

  create.flash nil
  create.wants.html { redirect_back_or_default(root_url) }

  new_action.before do
    flash.now[:notice] = I18n.t(:please_create_user) unless User.admin_created?
  end

  update.success.wants.html do
    if params[:user][:password].present?
      # this logic needed b/c devise wants to log us out after password changes
      user = User.reset_password_by_token(params[:user])
      sign_in(@user, :event => :authentication)
      #sign_in_and_redirect()
    end
    flash.notice = I18n.t("account_updated")
    redirect_to account_url
  end

  private
  def object
    @object ||= current_user
  end

  def accurate_title
    I18n.t(:account)
  end

  def associate_user
    return unless current_order and @user.valid?
    current_order.associate_user!(@user)
    session[:guest_token] = nil
  end

end

