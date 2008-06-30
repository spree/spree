require File.dirname(__FILE__) + '/../test_helper'
require 'people_controller'

# Re-raise errors caught by the controller.
class PeopleController; def rescue_action(e) raise e end; end

class PeopleControllerTest < Test::Unit::TestCase
  def setup
    @controller = PeopleController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @person     = accounts :one
  end

  should_be_restful do |resource|
    resource.formats = [:html]
    resource.klass   = Account
    resource.object  = :person
    
    resource.create.redirect = 'person_url(@person)'
    resource.update.redirect = 'person_url(@person)'
    resource.destroy.redirect = 'people_url'
  end
  
  context "before create" do
    setup do
      post :create, :person => {}
    end

    should "name account Bob Loblaw" do
      assert_equal "Bob Loblaw", assigns(:person).name
    end
  end
end
