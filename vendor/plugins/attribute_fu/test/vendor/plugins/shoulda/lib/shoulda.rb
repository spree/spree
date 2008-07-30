require 'yaml'
require 'shoulda/private_helpers'
require 'shoulda/general'
require 'shoulda/context'
require 'shoulda/active_record_helpers'


module Test # :nodoc: all
  module Unit 
    class TestCase

      include ThoughtBot::Shoulda::General

      class << self
        include ThoughtBot::Shoulda::Context
        include ThoughtBot::Shoulda::ActiveRecord
      end
    end
  end
end
