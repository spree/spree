require File.dirname(__FILE__) + '/../../spec_helper'

describe "A template with an implicit helper", :type => :view do
  before(:each) do
    render "view_spec/implicit_helper"
  end

  it "should include the helper" do
    response.should have_tag('div', :content => "This is text from a method in the ViewSpecHelper")
  end

  it "should include the application helper" do
    response.should have_tag('div', :content => "This is text from a method in the ApplicationHelper")
  end

  it "should have access to named routes" do
    rspec_on_rails_specs_url.should == "http://test.host/rspec_on_rails_specs"
    rspec_on_rails_specs_path.should == "/rspec_on_rails_specs"
  end
end

describe "A template requiring an explicit helper", :type => :view do
  before(:each) do
    render "view_spec/explicit_helper", :helper => 'explicit'
  end

  it "should include the helper if specified" do
    response.should have_tag('div', :content => "This is text from a method in the ExplicitHelper")
  end

  it "should include the application helper" do
    response.should have_tag('div', :content => "This is text from a method in the ApplicationHelper")
  end
end

describe "A template requiring multiple explicit helpers", :type => :view do
  before(:each) do
    render "view_spec/multiple_helpers", :helpers => ['explicit', 'more_explicit']
  end

  it "should include all specified helpers" do
    response.should have_tag('div', :content => "This is text from a method in the ExplicitHelper")
    response.should have_tag('div', :content => "This is text from a method in the MoreExplicitHelper")
  end

  it "should include the application helper" do
    response.should have_tag('div', :content => "This is text from a method in the ApplicationHelper")
  end
end

describe "Message Expectations on helper methods", :type => :view do
  it "should work" do
    template.should_receive(:method_in_plugin_application_helper).and_return('alternate message 1')
    render "view_spec/implicit_helper"
    response.body.should =~ /alternate message 1/
  end

  it "should work twice" do
    template.should_receive(:method_in_plugin_application_helper).and_return('alternate message 2')
    render "view_spec/implicit_helper"
    response.body.should =~ /alternate message 2/
  end
end

describe "A template that includes a partial", :type => :view do
  def render!
    render "view_spec/template_with_partial"
  end

  it "should render the enclosing template" do
    render!
    response.should have_tag('div', "method_in_partial in ViewSpecHelper")
  end

  it "should render the partial" do
    render!
    response.should have_tag('div', "method_in_template_with_partial in ViewSpecHelper")
  end

  it "should include the application helper" do
    render!
    response.should have_tag('div', "This is text from a method in the ApplicationHelper")
  end
  
  it "should pass expect_render with the right partial" do
    template.expect_render(:partial => 'partial')
    render!
    template.verify_rendered
  end
  
  it "should fail expect_render with the wrong partial" do
    template.expect_render(:partial => 'non_existent')
    render!
    begin
      template.verify_rendered
    rescue Spec::Mocks::MockExpectationError => e
    ensure
      e.backtrace.find{|line| line =~ /view_spec_spec\.rb\:92/}.should_not be_nil
    end
  end
  
  it "should pass expect_render when a partial is expected twice and happens twice" do
    template.expect_render(:partial => 'partial_used_twice').twice
    render!
    template.verify_rendered
  end
  
  it "should pass expect_render when a partial is expected once and happens twice" do
    template.expect_render(:partial => 'partial_used_twice')
    render!
    begin
      template.verify_rendered
    rescue Spec::Mocks::MockExpectationError => e
    ensure
      e.backtrace.find{|line| line =~ /view_spec_spec\.rb\:109/}.should_not be_nil
    end
  end
  
  it "should fail expect_render with the right partial but wrong options" do
    template.expect_render(:partial => 'partial', :locals => {:thing => Object.new})
    render!
    lambda {template.verify_rendered}.should raise_error(Spec::Mocks::MockExpectationError)
  end
end

describe "A partial that includes a partial", :type => :view do
  it "should support expect_render with nested partial" do
    obj = Object.new
    template.expect_render(:partial => 'partial', :object => obj)
    render :partial => "view_spec/partial_with_sub_partial", :locals => { :partial => obj }
  end
end

describe "A view that includes a partial using :collection and :spacer_template", :type => :view  do
  it "should render the partial w/ spacer_tamplate" do
    render "view_spec/template_with_partial_using_collection"
    response.should have_tag('div',/method_in_partial/)
    response.should have_tag('div',/ApplicationHelper/)
    response.should have_tag('div',/ViewSpecHelper/)
    response.should have_tag('hr#spacer')
  end

  it "should render the partial" do
    template.expect_render(:partial => 'partial',
               :collection => ['Alice', 'Bob'],
               :spacer_template => 'spacer')
    render "view_spec/template_with_partial_using_collection"
  end

end

describe "A view that includes a partial using an array as partial_path", :type => :view do
  before(:each) do
    module ActionView::Partials
      def render_template_with_partial_with_array_support(partial_path, local_assigns = nil, deprecated_local_assigns = nil)
        if partial_path.is_a?(Array)
          "Array Partial"
        else
          render_partial_without_array_support(partial_path, local_assigns, deprecated_local_assigns)
        end
      end

      alias :render_partial_without_array_support :render_partial
      alias :render_partial :render_template_with_partial_with_array_support
    end

    @array = ['Alice', 'Bob']
    assigns[:array] = @array
  end

  after(:each) do
    module ActionView::Partials
      alias :render_template_with_partial_with_array_support :render_partial
      alias :render_partial :render_partial_without_array_support
      undef render_template_with_partial_with_array_support
    end
  end

  it "should render have the array passed through to render_partial without modification" do
    render "view_spec/template_with_partial_with_array" 
    response.body.should match(/^Array Partial$/)
  end
end

describe "Different types of renders (not :template)", :type => :view do
  it "should render partial with local" do
    render :partial => "view_spec/partial_with_local_variable", :locals => {:x => "Ender"}
    response.should have_tag('div', :content => "Ender")
  end
end

describe "A view", :type => :view do
  before(:each) do
    session[:key] = "session"
    params[:key] = "params"
    flash[:key] = "flash"
    render "view_spec/accessor"
  end

  it "should have access to session data" do
    response.should have_tag("div#session", "session")
  end

  specify "should have access to params data" do
    response.should have_tag("div#params", "params")
  end

  it "should have access to flash data" do
    response.should have_tag("div#flash", "flash")
  end
end

describe "A view with a form_tag", :type => :view do
  it "should render the right action" do
    render "view_spec/entry_form"
    response.should have_tag("form[action=?]","/view_spec/entry_form")
  end
end

describe "An instantiated ViewExampleGroupController", :type => :view do
  before do
    render "view_spec/foo/show"
  end
  
  it "should return the name of the real controller that it replaces" do
    @controller.controller_name.should == 'foo'
  end
  
  it "should return the path of the real controller that it replaces" do
    @controller.controller_path.should == 'view_spec/foo'
  end
end

module Spec
  module Rails
    module Example
      describe ViewExampleGroup do
        it "should clear its name from the description" do
          group = describe("foo", :type => :view) do
            $nested_group = describe("bar") do
            end
          end
          group.description.to_s.should == "foo"
          $nested_group.description.to_s.should == "foo bar"
        end

        it "should clear ActionView::Base.base_view_path on teardown" do
          ViewExampleGroup.class_eval do
            alias_method(:ensure_that_base_view_path_is_not_set_across_example_groups_orig,
              :ensure_that_base_view_path_is_not_set_across_example_groups)
            define_method(:ensure_that_base_view_path_is_not_set_across_example_groups){
              $base_view_path_cleared = true
              ensure_that_base_view_path_is_not_set_across_example_groups_orig
            }
          end
          describe("base_view_path_cleared flag", :type => :view) do
            it { $base_view_path_cleared.should be_true }
          end
        end
      end
    end
  end
end
