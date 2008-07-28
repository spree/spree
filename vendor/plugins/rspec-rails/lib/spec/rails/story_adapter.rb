# WARNING - THIS IS PURELY EXPERIMENTAL AT THIS POINT
# Courtesy of Brian Takita and Yurii Rashkovskii

$:.unshift File.join(File.dirname(__FILE__), *%w[.. .. .. .. rspec lib])
if defined?(ActiveRecord::Base)
  require 'test_help' 
else
  require 'action_controller/test_process'
  require 'action_controller/integration'
end
require 'test/unit/testresult'
require 'spec'
require 'spec/rails'

Test::Unit.run = true

ActionController::Integration::Session.send(:include, Spec::Matchers)
ActionController::Integration::Session.send(:include, Spec::Rails::Matchers)

class RailsStory < ActionController::IntegrationTest
  if defined?(ActiveRecord::Base)
    self.use_transactional_fixtures = true
  else
    def self.fixture_table_names; []; end # Workaround for projects that don't use ActiveRecord
  end

  def initialize #:nodoc:
    # TODO - eliminate this hack, which is here to stop
    # Rails Stories from dumping the example summary.
    Spec::Runner::Options.class_eval do
      def examples_should_be_run?
        false
      end
    end
    @_result = Test::Unit::TestResult.new
  end
end

class ActiveRecordSafetyListener
  include Singleton
  def scenario_started(*args)
    if defined?(ActiveRecord::Base)
      ActiveRecord::Base.send :increment_open_transactions unless Rails::VERSION::STRING == "1.1.6"
      ActiveRecord::Base.connection.begin_db_transaction
    end
  end

  def scenario_succeeded(*args)
    if defined?(ActiveRecord::Base)
      ActiveRecord::Base.connection.rollback_db_transaction
      ActiveRecord::Base.send :decrement_open_transactions unless Rails::VERSION::STRING == "1.1.6"
    end
  end
  alias :scenario_pending :scenario_succeeded
  alias :scenario_failed :scenario_succeeded
end

class Spec::Story::Runner::ScenarioRunner
  def initialize
    @listeners = [ActiveRecordSafetyListener.instance]
  end
end

class Spec::Story::GivenScenario
  def perform(instance, name = nil)
    scenario = Spec::Story::Runner::StoryRunner.scenario_from_current_story @name
    runner = Spec::Story::Runner::ScenarioRunner.new
    runner.instance_variable_set(:@listeners,[])
    runner.run(scenario, instance)
  end
end
