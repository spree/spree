Spree::Admin::ResourceController.class_eval do
  rescue_from CanCan::AccessDenied, :with => :unauthorized
end
