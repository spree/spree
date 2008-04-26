require File.dirname(__FILE__) + '/../test_helper'

class <%= class_name %>Test < Test::Unit::TestCase
  
  # Replace this with your real tests.
  def test_this_extension
    flunk
  end
  
  def test_initialization
    assert_equal File.join(File.expand_path(RAILS_ROOT), 'vendor', 'extensions', '<%= file_name %>'), <%= class_name %>.root
    assert_equal '<%= extension_name %>', <%= class_name %>.extension_name
  end
  
end
