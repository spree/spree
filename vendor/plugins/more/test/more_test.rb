require 'test_helper'

class MoreTest < Test::Unit::TestCase
  def setup
    Less::More.class_eval do
      ["@compression", "@header"].each {|v|
        remove_instance_variable(v) if instance_variable_defined?(v)
      }
    end
  end
  

  def test_getting_config_from_current_environment_or_defaults_to_production
    Less::More::DEFAULTS["development"]["foo"] = 5
    Less::More::DEFAULTS["production"]["foo"] = 10
    
    Rails.expects(:env).returns("development")
    assert_equal 5, Less::More.get_cvar("foo")
    
    Rails.expects(:env).returns("production")
    assert_equal 10, Less::More.get_cvar("foo")
    
    Rails.expects(:env).returns("staging")
    assert_equal 10, Less::More.get_cvar("foo")
  end
  
  def test_user_settings_wins_over_defaults
    Less::More::DEFAULTS["development"][:compression] = true
    assert_equal true, Less::More.compression?
    
    Less::More::DEFAULTS["development"][:compression] = false
    assert_equal false, Less::More.compression?
    
    Less::More.compression = true
    assert_equal true, Less::More.compression?
  end
  
  def test_page_cache_is_read_from_environment_configs
    Less::More.expects(:heroku?).returns(false).times(2)
    
    Less::More.expects(:page_cache_enabled_in_environment_configuration?).returns(true)
    assert_equal true, Less::More.page_cache?
    
    Less::More.expects(:page_cache_enabled_in_environment_configuration?).returns(false)
    assert_equal false, Less::More.page_cache?
  end
  
  def test_page_cache_off_on_heroku
    Less::More.page_cache = true
    Less::More::DEFAULTS["development"][:page_cache] = true
    
    # The party pooper
    Less::More.expects(:heroku?).returns(true)
    
    assert_equal false, Less::More.page_cache?
  end
  
  def test_compression
    Less::More.compression = true
    assert_equal Less::More.compression?, true
    
    Less::More.compression = false
    assert_equal Less::More.compression?, false
  end
  
  def test_source_path
    Less::More.source_path = "/path/to/flaf"
    assert_equal Pathname.new("/path/to/flaf"), Less::More.source_path
  end
  
  def test_exists
    Less::More.source_path = File.join(File.dirname(__FILE__), 'less_files')
    
    assert Less::More.exists?(["test"])
    assert Less::More.exists?(["short"])
    assert Less::More.exists?(["sub", "test2"])
    
    # Partials does not exist
    assert !Less::More.exists?(["_global"])
    assert !Less::More.exists?(["shared", "_form"])
  end
  
  def test_generate
    Less::More.source_path = File.join(File.dirname(__FILE__), 'less_files')
    Less::More.compression = true
    
    assert Less::More.generate(["test"]).include?(".allforms { font-size: 110%; }body { color: #222222; }form {  font-size: 110%;  color: #ffffff;}")
  end
  
  def test_header
    Less::More.expects(:header?).returns(false)
    Less::More.source_path = File.join(File.dirname(__FILE__), 'less_files')
    assert !Less::More.generate(["test"]).starts_with?("/*")
    
    Less::More.expects(:header?).returns(true)
    Less::More.source_path = File.join(File.dirname(__FILE__), 'less_files')
    assert Less::More.generate(["test"]).starts_with?("/*")
  end
  
  def test_pathname_from_array
    Less::More.source_path = File.join(File.dirname(__FILE__), 'less_files')
    
    assert Less::More.pathname_from_array(["test"]).exist?
    assert Less::More.pathname_from_array(["short"]).exist?
    assert Less::More.pathname_from_array(["sub", "test2"]).exist?
  end
end
