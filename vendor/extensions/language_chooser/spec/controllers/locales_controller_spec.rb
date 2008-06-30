require File.dirname(__FILE__) + '/../spec_helper'

describe LocalesController do

  #Delete these examples and add some real ones
  it "should use LocalesController" do
    controller.should be_an_instance_of(LocalesController)
  end


  it "GET 'update' should be successful" do
    get 'update'
    response.should be_redirect
  end
end
