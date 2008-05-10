require File.dirname(__FILE__) + '/../../test_helper'
require 'cms/products_controller'

# Re-raise errors caught by the controller.
class Cms::ProductsController; def rescue_action(e) raise e end; end

class Cms::ProductsControllerTest < Test::Unit::TestCase
  def setup
    @controller = Cms::ProductsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @product    = Product.find 1
  end

  should_be_restful do |resource|
    resource.formats = [:html]
  end
end
