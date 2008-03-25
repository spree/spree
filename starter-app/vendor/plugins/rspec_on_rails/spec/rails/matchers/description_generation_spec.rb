require File.dirname(__FILE__) + '/../../spec_helper'

class DescriptionGenerationSpecController < ActionController::Base
  def render_action
  end

  def redirect_action
    redirect_to :action => :render_action
  end
end

describe "Description generation", :type => :controller do
  controller_name :description_generation_spec
  
  after(:each) do
    Spec::Matchers.clear_generated_description
  end

  it "should generate description for render_template" do
    get 'render_action'
    response.should render_template("render_action")
    Spec::Matchers.generated_description.should == "should render template \"render_action\""
  end

  it "should generate description for render_template with full path" do
    get 'render_action'
    response.should render_template("description_generation_spec/render_action")
    Spec::Matchers.generated_description.should == "should render template \"description_generation_spec/render_action\""
  end

  it "should generate description for redirect_to" do
    get 'redirect_action'
    response.should redirect_to("http://test.host/description_generation_spec/render_action")
    Spec::Matchers.generated_description.should == "should redirect to \"http://test.host/description_generation_spec/render_action\""
  end

end
