require File.dirname(__FILE__) + '<%= '/..' * controller_class_nesting_depth %>/../test_helper'
require '<%= controller_file_path %>_controller'

# Re-raise errors caught by the controller.
class <%= controller_class_name %>Controller; def rescue_action(e) raise e end; end

class <%= controller_class_name %>ControllerTest < Test::Unit::TestCase
  def setup
    @controller           = <%= controller_class_name %>Controller.new
    @request              = ActionController::TestRequest.new
    @response             = ActionController::TestResponse.new
    @<%= singular_name %> = <%= plural_name %> :one
  end

  should_be_restful do |resource|
    resource.formats = [:html]
  end

end
