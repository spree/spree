module Spec
  module Matchers
    class Have #:nodoc:
      def initialize(expected, relativity=:exactly)
        @expected = (expected == :no ? 0 : expected)
        @relativity = relativity
      end
    
      def relativities
        @relativities ||= {
          :exactly => "",
          :at_least => "at least ",
          :at_most => "at most "
        }
      end
    
      def matches?(collection_owner)
        if collection_owner.respond_to?(@collection_name)
          collection = collection_owner.__send__(@collection_name, *@args, &@block)
        elsif (@plural_collection_name && collection_owner.respond_to?(@plural_collection_name))
          collection = collection_owner.__send__(@plural_collection_name, *@args, &@block)
        elsif (collection_owner.respond_to?(:length) || collection_owner.respond_to?(:size))
          collection = collection_owner
        else
          collection_owner.__send__(@collection_name, *@args, &@block)
        end
        @given = collection.size if collection.respond_to?(:size)
        @given = collection.length if collection.respond_to?(:length)
        raise not_a_collection if @given.nil?
        return @given >= @expected if @relativity == :at_least
        return @given <= @expected if @relativity == :at_most
        return @given == @expected
      end
      
      def not_a_collection
        "expected #{@collection_name} to be a collection but it does not respond to #length or #size"
      end
    
      def failure_message
        "expected #{relative_expectation} #{@collection_name}, got #{@given}"
      end

      def negative_failure_message
        if @relativity == :exactly
          return "expected target not to have #{@expected} #{@collection_name}, got #{@given}"
        elsif @relativity == :at_most
          return <<-EOF
Isn't life confusing enough?
Instead of having to figure out the meaning of this:
  should_not have_at_most(#{@expected}).#{@collection_name}
We recommend that you use this instead:
  should have_at_least(#{@expected + 1}).#{@collection_name}
EOF
        elsif @relativity == :at_least
          return <<-EOF
Isn't life confusing enough?
Instead of having to figure out the meaning of this:
  should_not have_at_least(#{@expected}).#{@collection_name}
We recommend that you use this instead:
  should have_at_most(#{@expected - 1}).#{@collection_name}
EOF
        end
      end
      
      def description
        "have #{relative_expectation} #{@collection_name}"
      end
      
      def respond_to?(sym)
        @expected.respond_to?(sym) || super
      end
    
      private
      
      def method_missing(sym, *args, &block)
        @collection_name = sym
        if inflector = (defined?(ActiveSupport::Inflector) ? ActiveSupport::Inflector : (defined?(Inflector) ? Inflector : nil))
          @plural_collection_name = inflector.pluralize(sym.to_s)
        end
        @args = args
        @block = block
        self
      end
      
      def relative_expectation
        "#{relativities[@relativity]}#{@expected}"
      end
    end

    # :call-seq:
    #   should have(number).named_collection__or__sugar
    #   should_not have(number).named_collection__or__sugar
    #
    # Passes if receiver is a collection with the submitted
    # number of items OR if the receiver OWNS a collection
    # with the submitted number of items.
    #
    # If the receiver OWNS the collection, you must use the name
    # of the collection. So if a <tt>Team</tt> instance has a
    # collection named <tt>#players</tt>, you must use that name
    # to set the expectation.
    #
    # If the receiver IS the collection, you can use any name
    # you like for <tt>named_collection</tt>. We'd recommend using
    # either "elements", "members", or "items" as these are all
    # standard ways of describing the things IN a collection.
    #
    # This also works for Strings, letting you set an expectation
    # about its length
    #
    # == Examples
    #
    #   # Passes if team.players.size == 11
    #   team.should have(11).players
    #
    #   # Passes if [1,2,3].length == 3
    #   [1,2,3].should have(3).items #"items" is pure sugar
    #
    #   # Passes if "this string".length == 11
    #   "this string".should have(11).characters #"characters" is pure sugar
    def have(n)
      Matchers::Have.new(n)
    end
    alias :have_exactly :have

    # :call-seq:
    #   should have_at_least(number).items
    #
    # Exactly like have() with >=.
    #
    # == Warning
    #
    # +should_not+ +have_at_least+ is not supported
    def have_at_least(n)
      Matchers::Have.new(n, :at_least)
    end

    # :call-seq:
    #   should have_at_most(number).items
    #
    # Exactly like have() with <=.
    #
    # == Warning
    #
    # +should_not+ +have_at_most+ is not supported
    def have_at_most(n)
      Matchers::Have.new(n, :at_most)
    end
  end
end
