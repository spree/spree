require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe CountriesController do
  fixtures :countries

  #Delete this example and add some real ones
  it "should use CountriesController" do
    controller.should be_an_instance_of(CountriesController)
  end

  #it "should include AuthenticatedSystem" do
  #  controller.class.included_modules.should include(AuthenticatedSystem)
  #end
  it "should not allow deletion of a county from a default rails route" 
=begin  
  do
    lambda {
      get :destroy, :id => countries(:united_states).id
    }.should raise_error(ActionController::RoutingError)

    Country.find_by_id(countries(:united_states).id).should_not be_nil
  end
=end
end
