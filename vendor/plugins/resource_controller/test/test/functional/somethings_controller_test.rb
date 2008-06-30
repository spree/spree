require File.dirname(__FILE__) + '/../test_helper'
require 'somethings_controller'

# Re-raise errors caught by the controller.
class SomethingsController; def rescue_action(e) raise e end; end

class SomethingsControllerTest < Test::Unit::TestCase
  def setup
    @controller = SomethingsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @something  = somethings :one
  end

  context "actions specified" do
    [:create, :edit, :update, :destroy, :new].each do |action|
      should "not respond to #{action}" do
        assert !@controller.respond_to?(action)
      end
    end
  end
  
  should_be_restful do |resource|
    resource.formats = [:html]
    
    resource.actions = [:index, :show]
  end
end
