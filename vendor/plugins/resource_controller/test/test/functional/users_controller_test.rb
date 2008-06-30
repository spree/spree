require File.dirname(__FILE__) + '/../test_helper'
require 'users_controller'

# Re-raise errors caught by the controller.
class UsersController; def rescue_action(e) raise e end; end

class UsersControllerTest < Test::Unit::TestCase
  def setup
    @controller = UsersController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @dude       = accounts :one
  end

  should_be_restful do |resource|
    resource.formats = [:html]
    resource.klass   = Account
    resource.object  = :dude
    
    resource.create.redirect = 'dude_url(@dude)'
    resource.update.redirect = 'dude_url(@dude)'
    resource.destroy.redirect = 'dudes_url'
  end  
end
