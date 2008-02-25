require File.dirname(__FILE__) + '/../test_helper'
require 'application'

# Re-raise errors caught by the controller.
class ApplicationController; def rescue_action(e) raise e end; end

# open up protected methods for testing
#class ApplicationController
#  public :login_or_anonymous  
#end
  
class ApplicationControllerTest < Test::Unit::TestCase

  def setup
    @controller = ApplicationController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_truth
    assert true
  end
  #def test_login_or_anonymous
    #@controller.request = @request
    #@controller.session = {}
    #@controller.response = @response
    #assert @controller.login_or_anonymous, "should be anonymously authenticated"
    #TODO - add tests for other scenarios
  #end
end
