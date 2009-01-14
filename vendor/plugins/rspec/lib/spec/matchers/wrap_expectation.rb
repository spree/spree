module Spec
  module Matchers
    # wraps an expectation in a block that will return true if the
    # expectation passes and false if it fails (without bubbling up
    # the failure).
    #     
    # This is intended to be used in the context of a simple matcher,
    # and is especially useful for wrapping multiple expectations or
    # one or more assertions from test/unit extensions when running
    # with test/unit.
    #
    # == Examples
    #
    #   def eat_cheese(cheese)
    #     simple_matcher do |mouse, matcher|
    #       matcher.failure_message = "expected #{mouse} to eat cheese"
    #       wrap_expectation do |matcher|
    #         assert_eats_cheese(mouse)
    #       end
    #     end
    #   end
    #
    #   describe Mouse do
    #     it "eats cheese" do
    #       Mouse.new.should eat_cheese
    #     end
    #   end
    #
    # You might be wondering "why would I do this if I could just say"
    # assert_eats_cheese?", a fair question, indeed. You might prefer
    # to replace the word assert with something more aligned with the
    # rest of your code examples. You are using rspec, after all.
    #
    # The other benefit you get is that you can use the negative version
    # of the matcher:
    #
    #   describe Cat do
    #     it "does not eat cheese" do
    #       Cat.new.should_not eat_cheese
    #     end
    #   end
    #
    # So in the event there is no assert_does_not_eat_cheese available,
    # you're all set!
    def wrap_expectation(matcher, &block)
      begin
        block.call(matcher)
        return true
      rescue Exception => e
        matcher.failure_message = e.message
        return false
      end
    end
  end
end
