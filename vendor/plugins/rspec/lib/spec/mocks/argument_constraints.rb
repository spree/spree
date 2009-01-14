module Spec
  module Mocks

    # ArgumentConstraints are messages that you can include in message
    # expectations to match arguments against a broader check than simple
    # equality.
    #
    # With the exception of any_args() and no_args(), the constraints
    # are all positional - they match against the arg in the given position.
    module ArgumentConstraints

      class AnyArgsConstraint
        def description
          "any args"
        end
      end

      class AnyArgConstraint
        def initialize(ignore)
        end

        def ==(other)
          true
        end
      end

      class NoArgsConstraint
        def description
          "no args"
        end

        def ==(args)
          args == []
        end
      end

      class RegexpConstraint
        def initialize(regexp)
          @regexp = regexp
        end

        def ==(value)
          return value =~ @regexp unless value.is_a?(Regexp)
          value == @regexp
        end
      end

      class BooleanConstraint
        def initialize(ignore)
        end

        def ==(value)
          TrueClass === value || FalseClass === value
        end
      end

      class HashIncludingConstraint
        def initialize(expected)
          @expected = expected
        end

        def ==(actual)
          @expected.each do | key, value |
            return false unless actual.has_key?(key) && value == actual[key]
          end
          true
        rescue NoMethodError => ex
          return false
        end

        def description
          "hash_including(#{@expected.inspect.sub(/^\{/,"").sub(/\}$/,"")})"
        end
      end
      
      class HashNotIncludingConstraint
        def initialize(expected)
          @expected = expected
        end

        def ==(actual)
          @expected.each do | key, value |
            return false if actual.has_key?(key) && value == actual[key]
          end
          true
        rescue NoMethodError => ex
          return false
        end

        def description
          "hash_not_including(#{@expected.inspect.sub(/^\{/,"").sub(/\}$/,"")})"
        end
      end
      
      class DuckTypeConstraint
        def initialize(*methods_to_respond_to)
          @methods_to_respond_to = methods_to_respond_to
        end

        def ==(value)
          @methods_to_respond_to.all? { |sym| value.respond_to?(sym) }
        end
      end

      class MatcherConstraint
        def initialize(matcher)
          @matcher = matcher
        end

        def ==(value)
          @matcher.matches?(value)
        end
      end

      class EqualityProxy
        def initialize(given)
          @given = given
        end

        def ==(expected)
          @given == expected
        end
      end

      # :call-seq:
      #   object.should_receive(:message).with(any_args())
      #
      # Passes if object receives :message with any args at all. This is
      # really a more explicit variation of object.should_receive(:message)
      def any_args
        AnyArgsConstraint.new
      end
      
      # :call-seq:
      #   object.should_receive(:message).with(anything())
      #
      # Passes as long as there is an argument.
      def anything
        AnyArgConstraint.new(nil)
      end
      
      # :call-seq:
      #   object.should_receive(:message).with(no_args)
      #
      # Passes if no arguments are passed along with the message
      def no_args
        NoArgsConstraint.new
      end
      
      # :call-seq:
      #   object.should_receive(:message).with(duck_type(:hello))
      #   object.should_receive(:message).with(duck_type(:hello, :goodbye))
      #
      # Passes if the argument responds to the specified messages.
      #
      # == Examples
      #
      #   array = []
      #   display = mock('display')
      #   display.should_receive(:present_names).with(duck_type(:length, :each))
      #   => passes
      def duck_type(*args)
        DuckTypeConstraint.new(*args)
      end

      # :call-seq:
      #   object.should_receive(:message).with(boolean())
      #
      # Passes if the argument is boolean.
      def boolean
        BooleanConstraint.new(nil)
      end
      
      # :call-seq:
      #   object.should_receive(:message).with(hash_including(:key => val))
      #   object.should_receive(:message).with(hash_including(:key))
      #   object.should_receive(:message).with(hash_including(:key, :key2 => val2))
      # Passes if the argument is a hash that includes the specified key(s) or key/value
      # pairs. If the hash includes other keys, it will still pass.
      def hash_including(*args)
        HashIncludingConstraint.new(anythingize_lonely_keys(*args))
      end
      
      # :call-seq:
      #   object.should_receive(:message).with(hash_not_including(:key => val))
      #   object.should_receive(:message).with(hash_not_including(:key))
      #   object.should_receive(:message).with(hash_not_including(:key, :key2 => :val2))
      #
      # Passes if the argument is a hash that doesn't include the specified key(s) or key/value
      def hash_not_including(*args)
        HashNotIncludingConstraint.new(anythingize_lonely_keys(*args))
      end
      
      private
      
      def anythingize_lonely_keys(*args)
        hash = args.last.class == Hash ? args.delete_at(-1) : {}
        args.each { | arg | hash[arg] = anything }
        hash
      end
    end
  end
end
