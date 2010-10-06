CheckoutController.class_eval do
  before_filter :associate_user
  before_filter :check_authorization
  before_filter :check_registration, :except => [:registration, :update_registration]

  helper :users

  def registration
    @user = User.new
  end

  def update_registration
    if current_order.update_attributes(params[:order])
      redirect_to checkout_path
    else
      render 'registration'
    end
  end

  private
  def check_authorization
    authorize!(:edit, current_order)
  end

  # Associates the order with the current_user when applicable.  This would only occur if user authenticated before starting
  # the order (since the authentication process also automatically assigns the newly authenticated user to the order.)
  def associate_user
    if current_order.user.anonymous? and current_user
      current_order.associate_user!(current_user)
    end
  end

  # Introduces a registration step whenever the +registration_step+ preference is true.
  def check_registration
    return unless Spree::Auth::Config[:registration_step]
    return if Spree::Config[:allow_guest_checkout] and current_order.email.present?
    return if current_user or not current_order.user.anonymous?
    store_location
    redirect_to checkout_registration_path
  end

  # Overrides the equivalent method defined in spree_core.  This variation of the method will ensure that users
  # are redirected to the tokenized order url unless authenticated as a registered user.
  def completion_route
    return order_path(@order) unless @order.user.anonymous?
    token_order_path(@order, @order.user.token)
  end

end
