require 'active_support/all'
module ControllerHacks
  def api_get(action, params={}, session=nil, flash=nil)
    api_process(action, params, session, flash, "GET")
  end

  def api_post(action, params={}, session=nil, flash=nil)
    api_process(action, params, session, flash, "POST")
  end

  def api_process(action, params={}, session=nil, flash=nil, method="get")
    process(action, params.reverse_merge!(:use_route => :spree, :format => :json, :key => "fake_key"), session, flash, method)
  end
end

RSpec.configure do |config|
  config.include ControllerHacks, :type => :controller
end
