class UserPasswordsController < Devise::PasswordsController
  include SpreeBase
  helper :users, 'spree/base'

  after_filter :associate_user, :only => :update

  def new
    super
  end

  def create
    super
  end

  def edit
    super
  end

  def update
    super
  end

  private

  def associate_user
    return unless current_user and current_order
    current_order.associate_user!(current_user)
    session[:guest_token] = nil
  end

end
