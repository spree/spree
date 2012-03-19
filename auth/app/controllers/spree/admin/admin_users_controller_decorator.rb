require File.expand_path('../../base_controller_decorator', __FILE__)
Spree::Admin::UsersController.class_eval do
  rescue_from Spree::User::DestroyWithOrdersError, :with => :user_destroy_with_orders_error
end

