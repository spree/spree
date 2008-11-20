unless defined? SPEC_ROOT
  ENV["RAILS_ENV"] = "test"
  
  SPEC_ROOT = File.expand_path(File.dirname(__FILE__))
  
  unless defined? SPREE_ROOT
    if env_file = ENV["SPREE_ENV_FILE"]
      require env_file
    else
      require File.expand_path(SPEC_ROOT + "/../config/environment")
    end
  end
  require 'spec'
  require 'spec/rails'
#  require 'scenarios'
  require File.expand_path(File.dirname(__FILE__) + "/preference_factory")
  
  class Test::Unit::TestCase
    class << self
      # Class method for test helpers
      def test_helper(*names)
        names.each do |name|
          name = name.to_s
          name = $1 if name =~ /^(.*?)_test_helper$/i
          name = name.singularize
          first_time = true
          begin
            constant = (name.camelize + 'TestHelper').constantize
            self.class_eval { include constant }
          rescue NameError
            filename = File.expand_path(SPEC_ROOT + '/../test/helpers/' + name + '_test_helper.rb')
            require filename if first_time
            first_time = false
            retry
          end
        end
      end    
      alias :test_helpers :test_helper
    end
  end
  
  Dir[SPREE_ROOT + '/spec/matchers/*_matcher.rb'].each do |matcher|
    require matcher
  end
  
#  Scenario.load_paths.unshift "#{SPREE_ROOT}/spec/scenarios"
  
  Spec::Runner.configure do |config|
    config.use_transactional_fixtures = true
    config.use_instantiated_fixtures  = false
    config.fixture_path = RAILS_ROOT + '/spec/fixtures/'
    
    # You can declare fixtures for each behaviour like this:
    #   describe "...." do
    #     fixtures :table_a, :table_b
    #
    # Alternatively, if you prefer to declare them only once, you can
    # do so here, like so ...
    #
    #   config.global_fixtures = :table_a, :table_b
    #
    # If you declare global fixtures, be aware that they will be declared
    # for all of your examples, even those that don't use them.
  end
end


class Hash
  def except(*keys)
    self.reject { |k,v| keys.include?(k || k.to_sym) }
  end

  def with(overrides = {})
    self.merge overrides
  end

  def only(*keys)
    self.reject { |k,v| !keys.include?(k || k.to_sym) }
  end
end