Spree::Admin::UsersController.class_eval do
  rescue_from Spree::User::DestroyWithOrdersError, :with => :user_destroy_with_orders_error
end

