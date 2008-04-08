require File.dirname(__FILE__) + '/../../spec_helper'

['isolation','integration'].each do |mode|
  describe "redirect_to behaviour", :type => :controller do
    if mode == 'integration'
      integrate_views
    end
    controller_name :redirect_spec
  
    it "redirected to another action" do
      get 'action_with_redirect_to_somewhere'
      response.should redirect_to(:action => 'somewhere')
    end
    
    it "redirected to another controller and action" do
      get 'action_with_redirect_to_other_somewhere'
      response.should redirect_to(:controller => 'render_spec', :action => 'text_action')
    end
    
    it "redirected to another action (with 'and return')" do
      get 'action_with_redirect_to_somewhere_and_return'
      response.should redirect_to(:action => 'somewhere')
    end
  
    it "redirected to correct path with leading /" do
      get 'action_with_redirect_to_somewhere'
      response.should redirect_to('/redirect_spec/somewhere')
    end
    
    it "redirected to correct path without leading /" do
      get 'action_with_redirect_to_somewhere'
      response.should redirect_to('redirect_spec/somewhere')
    end
    
    it "redirected to correct internal URL" do
      get 'action_with_redirect_to_somewhere'
      response.should redirect_to("http://test.host/redirect_spec/somewhere")
    end
  
    it "redirected to correct external URL" do
      get 'action_with_redirect_to_rspec_site'
      response.should redirect_to("http://rspec.rubyforge.org")
    end
  
    it "redirected :back" do
      request.env['HTTP_REFERER'] = "http://test.host/previous/page"
      get 'action_with_redirect_back'
      response.should redirect_to(:back)
    end
  
    it "redirected :back and should redirect_to URL matches" do
      request.env['HTTP_REFERER'] = "http://test.host/previous/page"
      get 'action_with_redirect_back'
      response.should redirect_to("http://test.host/previous/page")
    end
    
    it "redirected from within a respond_to block" do
      get 'action_with_redirect_in_respond_to'
      response.should redirect_to('redirect_spec/somewhere')
    end

    params_as_hash = {:action => "somewhere", :id => 1111, :param1 => "value1", :param2 => "value2"}

    it "redirected to an internal URL containing a query string" do
      get "action_with_redirect_which_creates_query_string"
      response.should redirect_to(params_as_hash)
    end

    it "redirected to an internal URL containing a query string, one way it might be generated" do
      get "action_with_redirect_with_query_string_order1"
      response.should redirect_to(params_as_hash)
    end

    it "redirected to an internal URL containing a query string, another way it might be generated" do
      get "action_with_redirect_with_query_string_order2"
      response.should redirect_to(params_as_hash)
    end

    it "redirected to an internal URL which is unroutable but matched via a string" do
      get "action_with_redirect_to_unroutable_url_inside_app"
      response.should redirect_to("http://test.host/nonexistant/none")
    end

  end

  
  describe "redirect_to with a controller spec in #{mode} mode and a custom request.host", :type => :controller do
    if mode == 'integration'
      integrate_views
    end
    controller_name :redirect_spec
    before do
      request.host = "some.custom.host"
    end
  
    it "should pass when redirected to another action" do
      get 'action_with_redirect_to_somewhere'
      response.should redirect_to(:action => 'somewhere')
    end
  end
  
  describe "Given a controller spec in #{mode} mode", :type => :controller do
    if mode == 'integration'
      integrate_views
    end
    controller_name :redirect_spec
  
    it "an action that redirects should not result in an error if no should redirect_to expectation is called" do
      get 'action_with_redirect_to_somewhere'
    end
    
    it "an action that redirects should not result in an error if should_not redirect_to expectation was called, but not to that action" do
      get 'action_with_redirect_to_somewhere'
      response.should_not redirect_to(:action => 'another_destination')
    end

    it "an action that redirects should result in an error if should_not redirect_to expectation was called to that action" do
      get 'action_with_redirect_to_somewhere'
      lambda {
        response.should_not redirect_to(:action => 'somewhere')
      }.should fail_with("expected not to be redirected to {:action=>\"somewhere\"}, but was")
    end

    it "an action that does not redirects should not result in an error if should_not redirect_to expectation was called" do
      get 'action_with_no_redirect'
      response.should_not redirect_to(:action => 'any_destination')
    end

    
  end
  
  describe "Given a controller spec in #{mode} mode, should redirect_to should fail when", :type => :controller do
    if mode == 'integration'
      integrate_views
    end
    controller_name :redirect_spec
    
    it "redirected to wrong action" do
      get 'action_with_redirect_to_somewhere'
      lambda {
        response.should redirect_to(:action => 'somewhere_else')
      }.should fail_with("expected redirect to {:action=>\"somewhere_else\"}, got redirect to \"http://test.host/redirect_spec/somewhere\"")
    end
    
    it "redirected to incorrect path with leading /" do
      get 'action_with_redirect_to_somewhere'
      lambda {
        response.should redirect_to('/redirect_spec/somewhere_else')
      }.should fail_with('expected redirect to "/redirect_spec/somewhere_else", got redirect to "http://test.host/redirect_spec/somewhere"')
    end
  
    it "redirected to incorrect path without leading /" do
      get 'action_with_redirect_to_somewhere'
      lambda {
        response.should redirect_to('redirect_spec/somewhere_else')
      }.should fail_with('expected redirect to "redirect_spec/somewhere_else", got redirect to "http://test.host/redirect_spec/somewhere"')
    end
  
    it "redirected to incorrect internal URL (based on the action)" do
      get 'action_with_redirect_to_somewhere'
      lambda {
        response.should redirect_to("http://test.host/redirect_spec/somewhere_else")
      }.should fail_with('expected redirect to "http://test.host/redirect_spec/somewhere_else", got redirect to "http://test.host/redirect_spec/somewhere"')
    end
    
    it "redirected to wrong external URL" do
      get 'action_with_redirect_to_rspec_site'
      lambda {
        response.should redirect_to("http://test.unit.rubyforge.org")
      }.should fail_with('expected redirect to "http://test.unit.rubyforge.org", got redirect to "http://rspec.rubyforge.org"')
    end
  
    it "redirected to incorrect internal URL (based on the directory path)" do
      get 'action_with_redirect_to_somewhere'
      lambda {
        response.should redirect_to("http://test.host/non_existent_controller/somewhere")
      }.should fail_with('expected redirect to "http://test.host/non_existent_controller/somewhere", got redirect to "http://test.host/redirect_spec/somewhere"')
    end
  
    it "expected redirect :back, but redirected to a new URL" do
      get 'action_with_no_redirect'
      lambda {
        response.should redirect_to(:back)
      }.should fail_with('expected redirect to :back, got no redirect')
    end
  
    it "no redirect at all" do
      get 'action_with_no_redirect'
      lambda {
        response.should redirect_to(:action => 'nowhere')
      }.should fail_with("expected redirect to {:action=>\"nowhere\"}, got no redirect")
    end
  
    it "redirected to an internal URL which is unroutable and matched via a hash" do
      get "action_with_redirect_to_unroutable_url_inside_app"
      route = {:controller => "nonexistant", :action => "none"}
      lambda {
        response.should redirect_to(route)
      }.should raise_error(ActionController::RoutingError, /(no route found to match|No route matches) \"\/nonexistant\/none\" with \{\}/)
    end

  end
end
