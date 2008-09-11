require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class InvalidTransitionTest < Test::Unit::TestCase
  def test_should_exist
    assert_not_nil PluginAWeek::StateMachine::InvalidTransition
  end
end
