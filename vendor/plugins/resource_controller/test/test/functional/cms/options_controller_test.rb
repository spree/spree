require File.dirname(__FILE__) + '/../../test_helper'
require 'cms/options_controller'

# Re-raise errors caught by the controller.
class Cms::OptionsController; def rescue_action(e) raise e end; end

class Cms::OptionsControllerTest < Test::Unit::TestCase
  def setup
    @controller = Cms::OptionsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @option     = Option.find 1
  end

  should_be_restful do |resource|
    resource.formats = [:html]
    resource.klass  = ::Option
    resource.parent = :product
    resource.update.redirect  = 'cms_product_option_path(@product, @option)'
    resource.destroy.redirect = 'cms_product_options_path(@product)'
    resource.create.redirect  = 'cms_product_option_path(@product, @option)'
  end
end
