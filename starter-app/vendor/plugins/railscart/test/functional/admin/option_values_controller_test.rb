require File.dirname(__FILE__) + '/../../test_helper'
require 'admin/option_values_controller'

# Re-raise errors caught by the controller.
class Admin::OptionValuesController; def rescue_action(e) raise e end; end

class Admin::OptionValuesControllerTest < Test::Unit::TestCase
  def setup
    @controller = Admin::OptionValuesController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
