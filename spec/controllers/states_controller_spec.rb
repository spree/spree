require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe StatesController do
  fixtures :states

  #it "should include AuthenticatedSystem" do
  #  controller.class.included_modules.should include(AuthenticatedSystem)
  #end

  it "should not allow deletion of a state from a default rails route" 
=begin  
  do
    lambda {
      get :destroy, :id => states(:new_york).id
    }.should raise_error(ActionController::RoutingError)
  end
=end
end