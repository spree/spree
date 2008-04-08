require File.join(File.dirname(__FILE__), *%w[helper])
require File.join(File.dirname(__FILE__), *%w[steps people])

# Run transactions_should_rollback in Ruby
require File.join(File.dirname(__FILE__), *%w[transactions_should_rollback])

# Run transactions_should_rollback in Plain Text
with_steps_for :people do
  run File.join(File.dirname(__FILE__), *%w[transactions_should_rollback]), :type => RailsStory
end