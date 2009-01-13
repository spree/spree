dir = File.dirname(__FILE__)
$LOAD_PATH.unshift(File.expand_path("#{dir}/../rspec/lib"))
$LOAD_PATH.unshift(File.expand_path("#{dir}/resources/controllers"))
$LOAD_PATH.unshift(File.expand_path("#{dir}/resources/helpers"))
require File.expand_path("#{dir}/../../../../spec/spec_helper")
require File.expand_path("#{dir}/resources/controllers/application")
require File.expand_path("#{dir}/resources/controllers/render_spec_controller")
require File.expand_path("#{dir}/resources/controllers/rjs_spec_controller")
require File.expand_path("#{dir}/resources/controllers/redirect_spec_controller")
require File.expand_path("#{dir}/resources/controllers/action_view_base_spec_controller")
require File.expand_path("#{dir}/resources/helpers/addition_helper")
require File.expand_path("#{dir}/resources/helpers/explicit_helper")
require File.expand_path("#{dir}/resources/helpers/more_explicit_helper")
require File.expand_path("#{dir}/resources/helpers/view_spec_helper")
require File.expand_path("#{dir}/resources/helpers/plugin_application_helper")

require File.expand_path("#{dir}/resources/models/animal")
require File.expand_path("#{dir}/resources/models/person")
require File.expand_path("#{dir}/resources/models/thing")

extra_controller_paths = File.expand_path("#{dir}/resources/controllers")

unless ActionController::Routing.controller_paths.include?(extra_controller_paths)
  ActionController::Routing.instance_eval {@possible_controllers = nil}
  ActionController::Routing.controller_paths << extra_controller_paths
end

module Spec
  module Rails
    module Example
      class ViewExampleGroupController
        set_view_path File.join(File.dirname(__FILE__), "..", "spec", "resources", "views")
      end
    end
  end
end

def fail()
  raise_error(Spec::Expectations::ExpectationNotMetError)
end
  
def fail_with(message)
  raise_error(Spec::Expectations::ExpectationNotMetError,message)
end

class Proc
  def should_pass
    lambda { self.call }.should_not raise_error
  end
end

Spec::Runner.configure do |config|
  config.before(:each, :type => :controller) do
  end
end


ActionController::Routing::Routes.clear! # only since we're drawing routes here
ActionController::Routing::Routes.draw do |map|
  map.resources :rspec_on_rails_specs
  map.connect 'custom_route', :controller => 'custom_route_spec', :action => 'custom_route'
  map.connect ":controller/:action/:id"
end

