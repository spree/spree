require 'test/unit'
# Load the environment
unless defined? SPREE_ROOT
  ENV["RAILS_ENV"] = "test"
  case
  when ENV["SPREE_ENV_FILE"]
    require File.dirname(ENV["SPREE_ENV_FILE"]) + "/boot"
  when File.dirname(__FILE__) =~ %r{vendor/spree/vendor/extensions}
    require "#{File.expand_path(File.dirname(__FILE__) + "/../../../../../../")}/config/boot"
  else
    require "#{File.expand_path(File.dirname(__FILE__) + "/../../../../")}/config/boot"
  end
end
require "#{SPREE_ROOT}/test/test_helper"


module ApiIntegrationHelper

  def setup_user
    @user = Factory(:admin_user)
    @user.generate_api_key!
  end
  def valid_headers
    {'X-SpreeAPIKey' => @user.api_key, 'Accept' => 'application/json', 'Content-Type' => 'application/json'}
  end

  def get_with_key(path, params = nil)
    get path, params, valid_headers
  end
  def post_with_key(path, params = nil)
    post path, params, valid_headers
  end
  def put_with_key(path, params = nil)
    put path, params, valid_headers
  end
  def delete_with_key(path, params = nil)
    delete path, params, valid_headers
  end

end


class Test::Unit::TestCase

  def self.should_set_location_header(&block)
    should "Set the Location header" do
      expected_url = instance_eval(&block)
      assert_equal expected_url, response.headers['Location'], "wasn't set to '#{expected_url}'"
    end
  end

end

