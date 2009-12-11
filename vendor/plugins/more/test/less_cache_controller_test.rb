require 'test_helper'

class LessCacheControllerTest < ActionController::IntegrationTest
  def setup
    Less::More.source_path = File.join(File.dirname(__FILE__), 'less_files')
  end
  
  test "regular stylesheet" do
    Less::More.expects(:page_cache_enabled_in_environment_configuration?).returns(true).at_least_once
    get "stylesheets/test.css"
    assert_response :success
    assert @response.body.include?("body { color: #222222; }")
  end
  
  test "sub-folder" do
    Less::More.expects(:page_cache_enabled_in_environment_configuration?).returns(true).at_least_once
    get "stylesheets/sub/test2.css"
    assert_response :success
    assert @response.body.include?("div { display: none; }")
  end
  
  test "plain css stylesheet" do
    Less::More.expects(:page_cache_enabled_in_environment_configuration?).returns(true).at_least_once
    get "stylesheets/plain.css"
    assert_response :success
    assert @response.body.include?("div { width: 1 + 1 }")
  end
  
  test "404" do
    Less::More.expects(:page_cache_enabled_in_environment_configuration?).returns(true)
    Less::More.expects(:generate).never
    get "stylesheets/does_not_exist.css"
    assert_response 404
  end
  
  test "setting headers with page cache" do
    Less::More.expects(:page_cache?).returns(false)
    get "stylesheets/test.css"
    assert @response.headers["Cache-Control"]
  end
end
