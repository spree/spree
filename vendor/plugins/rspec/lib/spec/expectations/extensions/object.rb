module Spec
  module Expectations
    # rspec adds #should and #should_not to every Object (and,
    # implicitly, every Class).
    module ObjectExpectations
      # :call-seq:
      #   should(matcher)
      #   should == expected
      #   should === expected
      #   should =~ expected
      #
      #   receiver.should(matcher)
      #     => Passes if matcher.matches?(receiver)
      #
      #   receiver.should == expected #any value
      #     => Passes if (receiver == expected)
      #
      #   receiver.should === expected #any value
      #     => Passes if (receiver === expected)
      #
      #   receiver.should =~ regexp
      #     => Passes if (receiver =~ regexp)
      #
      # See Spec::Matchers for more information about matchers
      #
      # == Warning
      #
      # NOTE that this does NOT support receiver.should != expected.
      # Instead, use receiver.should_not == expected
      def should(matcher=nil, &block)
        ExpectationMatcherHandler.handle_matcher(self, matcher, &block)
      end

      # :call-seq:
      #   should_not(matcher)
      #   should_not == expected
      #   should_not === expected
      #   should_not =~ expected
      #
      #   receiver.should_not(matcher)
      #     => Passes unless matcher.matches?(receiver)
      #
      #   receiver.should_not == expected
      #     => Passes unless (receiver == expected)
      #
      #   receiver.should_not === expected
      #     => Passes unless (receiver === expected)
      #
      #   receiver.should_not =~ regexp
      #     => Passes unless (receiver =~ regexp)
      #
      # See Spec::Matchers for more information about matchers
      def should_not(matcher=nil, &block)
        NegativeExpectationMatcherHandler.handle_matcher(self, matcher, &block)
      end

    end
  end
end

class Object
  include Spec::Expectations::ObjectExpectations
end
