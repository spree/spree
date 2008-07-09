require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe Admin::ConfigurationsController do

  it "should inherit from Admin::BaseController" do
    controller.should be_a_kind_of(Admin::BaseController)
  end

end
