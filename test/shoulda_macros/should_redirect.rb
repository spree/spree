class ActiveSupport::TestCase
  def self.should_redirect_to_thanks
    should_redirect_to("thank you page") { order_url(@order) }
  end
  def self.should_redirect_to_register
    should_redirect_to("registration") { register_order_checkout_url(@order) }
  end
  def self.should_redirect_to_first_step
    should_redirect_to("first step of checkout") { edit_order_checkout_url(@order) }
  end
  def self.should_redirect_to_authorization_failure
    should_redirect_to("login") { "/user_sessions/authorization_failure" }
  end
end

