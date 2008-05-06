require File.dirname(__FILE__) + '<%= '/..' * class_nesting_depth %>/../test_helper'

# Re-raise errors caught by the controller.
<%= class_name %>Controller.class_eval { def rescue_action(e) raise e end }

class <%= class_name %>ControllerTest < Test::Unit::TestCase
  def setup
    @controller = <%= class_name %>Controller.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
