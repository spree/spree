require File.dirname(__FILE__) + '/../../test_helper'
require 'admin/variations_controller'

# Re-raise errors caught by the controller.
class Admin::VariationsController; def rescue_action(e) raise e end; end

class Admin::VariationsControllerTest < Test::Unit::TestCase
  def setup
    @controller = Admin::VariationsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
