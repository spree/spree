module Spec
  module Matchers
    def self.last_matcher
      @last_matcher
    end

    def self.last_matcher=(last_matcher)
      @last_matcher = last_matcher
    end

    def self.last_should
      @last_should
    end

    def self.last_should=(last_should)
      @last_should = last_should
    end

    def self.clear_generated_description
      self.last_matcher = nil
      self.last_should = nil
    end

    def self.generated_description
      return nil if last_should.nil?
      "#{last_should} #{last_description}"
    end
    
    private
    
    def self.last_description
      last_matcher.respond_to?(:description) ? last_matcher.description : <<-MESSAGE
When you call a matcher in an example without a String, like this:

specify { object.should matcher }

or this:

it { should matcher }

the runner expects the matcher to have a #describe method. You should either
add a String to the example this matcher is being used in, or give it a
description method. Then you won't have to suffer this lengthy warning again.
MESSAGE
    end
  end
end
      