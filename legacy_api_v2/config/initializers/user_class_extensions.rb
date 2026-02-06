# Ensure that Spree.user_class includes the UserApiMethods concern

Spree::Core::Engine.config.to_prepare do
  if Spree.user_class && !Spree.user_class.included_modules.include?(Spree::UserApiMethods)
    Spree.user_class.include Spree::UserApiMethods
  end
end
