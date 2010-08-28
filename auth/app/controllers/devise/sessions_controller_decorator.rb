Devise::SessionsController.class_eval do
  after_filter :associate_user, :only => :create

  include Spree::CurrentOrder
  include Spree::AuthUser

  def associate_user
    return unless current_user and current_order
    current_order.associate_user!(current_user) if can? :edit, current_order
    session[:guest_token] = nil
  end
end