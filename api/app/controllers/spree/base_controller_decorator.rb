require_dependency 'spree/base_controller'

Spree::BaseController.class_eval do
  before_filter :ensure_api_key

  # Need to generate an API key for a user due to some actions potentially
  # requiring authentication to the Spree API
  def ensure_api_key
    if user = try_spree_current_user
      if user.respond_to?(:spree_api_key) && user.spree_api_key.blank?
        user.generate_spree_api_key!
      end
    end
  end
end
