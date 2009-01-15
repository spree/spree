silence_warnings { RAILS_ENV = "test" }

begin
  require_dependency 'application_controller'
rescue MissingSourceFile
  require_dependency 'application'
end

require 'action_controller/test_process'
require 'action_controller/integration'
require 'active_record/fixtures' if defined?(ActiveRecord::Base)
require 'test/unit'

require 'spec'

if Spec.class != Module
  raise "Uh oh, we didn't load RSpec.  Do you have a model named Spec?  You need to rename it!"
end

require 'spec/rails/matchers'
require 'spec/rails/mocks'
require 'spec/rails/example'
require 'spec/rails/extensions'
require 'spec/rails/interop/testcase'

# This is a temporary hack to get rspec's auto-runner functionality to not consider
# ActionMailer::TestCase to be a spec waiting to run.
require 'action_mailer/test_case'
Spec::Example::ExampleGroupFactory.register(:ignore_for_now, ActionMailer::TestCase)
