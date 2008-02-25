require File.dirname(__FILE__) + '/../test_helper'
require 'checkout_controller'

# Re-raise errors caught by the controller.
class CheckoutController; def rescue_action(e) raise e end; end

class CheckoutControllerTest < Test::Unit::TestCase
  include CheckoutHelper
  
  def setup
    @controller = CheckoutController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_truth
    assert true
  end
  
end
