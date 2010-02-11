require File.dirname(__FILE__) + '<%= '/..' * class_nesting_depth %>/../test_helper'

# Re-raise errors caught by the controller.
<%= class_name %>Controller.class_eval { def rescue_action(e) raise e end }

class <%= class_name %>ControllerTest < ActionController::TestCase

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
