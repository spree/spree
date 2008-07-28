require File.join(File.dirname(__FILE__), 'proc_extensions')

module Thoughtbot
  module Shoulda
    class << self
      attr_accessor :current_context
    end

    VERSION = '1.1.1'

    # = Should statements
    #
    # Should statements are just syntactic sugar over normal Test::Unit test methods.  A should block 
    # contains all the normal code and assertions you're used to seeing, with the added benefit that 
    # they can be wrapped inside context blocks (see below).
    #
    # == Example:
    #
    #  class UserTest << Test::Unit::TestCase
    #    
    #    def setup
    #      @user = User.new("John", "Doe")
    #    end
    #
    #    should "return its full name"
    #      assert_equal 'John Doe', @user.full_name
    #    end
    #  
    #  end
    #   
    # ...will produce the following test:
    # * <tt>"test: User should return its full name. "</tt>
    #
    # Note: The part before <tt>should</tt> in the test name is gleamed from the name of the Test::Unit class.

    def should(name, &blk)
      if Shoulda.current_context
        Shoulda.current_context.should(name, &blk)
      else
        context_name = self.name.gsub(/Test/, "")
        context = Thoughtbot::Shoulda::Context.new(context_name, self) do
          should(name, &blk)
        end
        context.build
      end
    end

    # Just like should, but never runs, and instead prints an 'X' in the Test::Unit output.
    def should_eventually(name, &blk)
      context_name = self.name.gsub(/Test/, "")
      context = Thoughtbot::Shoulda::Context.new(context_name, self) do
        should_eventually(name, &blk)
      end
      context.build
    end

    # = Contexts
    # 
    # A context block groups should statements under a common set of setup/teardown methods.  
    # Context blocks can be arbitrarily nested, and can do wonders for improving the maintainability
    # and readability of your test code.
    #
    # A context block can contain setup, should, should_eventually, and teardown blocks.
    #
    #  class UserTest << Test::Unit::TestCase
    #    context "A User instance" do
    #      setup do
    #        @user = User.find(:first)
    #      end
    #    
    #      should "return its full name"
    #        assert_equal 'John Doe', @user.full_name
    #      end
    #    end
    #  end
    #
    # This code will produce the method <tt>"test: A User instance should return its full name. "</tt>.
    #
    # Contexts may be nested.  Nested contexts run their setup blocks from out to in before each 
    # should statement.  They then run their teardown blocks from in to out after each should statement.
    #
    #  class UserTest << Test::Unit::TestCase
    #    context "A User instance" do
    #      setup do
    #        @user = User.find(:first)
    #      end
    #    
    #      should "return its full name"
    #        assert_equal 'John Doe', @user.full_name
    #      end
    #    
    #      context "with a profile" do
    #        setup do
    #          @user.profile = Profile.find(:first)
    #        end
    #      
    #        should "return true when sent :has_profile?"
    #          assert @user.has_profile?
    #        end
    #      end
    #    end
    #  end
    #
    # This code will produce the following methods 
    # * <tt>"test: A User instance should return its full name. "</tt>
    # * <tt>"test: A User instance with a profile should return true when sent :has_profile?. "</tt>
    #
    # <b>Just like should statements, a context block can exist next to normal <tt>def test_the_old_way; end</tt> 
    # tests</b>.  This means you do not have to fully commit to the context/should syntax in a test file.

    def context(name, &blk)
      if Shoulda.current_context
        Shoulda.current_context.context(name, &blk)
      else
        context = Thoughtbot::Shoulda::Context.new(name, self, &blk)
        context.build
      end
    end

    class Context # :nodoc:

      attr_accessor :name               # my name
      attr_accessor :parent             # may be another context, or the original test::unit class.
      attr_accessor :subcontexts        # array of contexts nested under myself
      attr_accessor :setup_block        # block given via a setup method
      attr_accessor :teardown_block     # block given via a teardown method
      attr_accessor :shoulds            # array of hashes representing the should statements
      attr_accessor :should_eventuallys # array of hashes representing the should eventually statements

      def initialize(name, parent, &blk)
        Shoulda.current_context = self
        self.name               = name
        self.parent             = parent
        self.setup_block        = nil
        self.teardown_block     = nil
        self.shoulds            = []
        self.should_eventuallys = []
        self.subcontexts        = []

        blk.bind(self).call
        Shoulda.current_context = nil
      end

      def context(name, &blk)
        subcontexts << Context.new(name, self, &blk)
        Shoulda.current_context = self
      end

      def setup(&blk)
        self.setup_block = blk
      end

      def teardown(&blk)
        self.teardown_block = blk
      end

      def should(name, &blk)
        self.shoulds << { :name => name, :block => blk }
      end

      def should_eventually(name, &blk)
        self.should_eventuallys << { :name => name, :block => blk }
      end

      def full_name
        parent_name = parent.full_name if am_subcontext?
        return [parent_name, name].join(" ").strip
      end

      def am_subcontext?
        parent.is_a?(self.class) # my parent is the same class as myself.
      end

      def test_unit_class
        am_subcontext? ? parent.test_unit_class : parent
      end

      def create_test_from_should_hash(should)
        test_name = ["test:", full_name, "should", "#{should[:name]}. "].flatten.join(' ').to_sym

        if test_unit_class.instance_methods.include?(test_name.to_s)
          warn "  * WARNING: '#{test_name}' is already defined" 
        end
        
        context = self
        test_unit_class.send(:define_method, test_name) do |*args|
          begin
            context.run_all_setup_blocks(self)
            should[:block].bind(self).call
          ensure
            context.run_all_teardown_blocks(self)
          end
        end
      end

      def run_all_setup_blocks(binding)
        self.parent.run_all_setup_blocks(binding) if am_subcontext?
        setup_block.bind(binding).call if setup_block
      end

      def run_all_teardown_blocks(binding)
        teardown_block.bind(binding).call if teardown_block
        self.parent.run_all_teardown_blocks(binding) if am_subcontext?
      end

      def print_should_eventuallys
        should_eventuallys.each do |should|
          test_name = [full_name, "should", "#{should[:name]}. "].flatten.join(' ')
          puts "  * DEFERRED: " + test_name
        end
        subcontexts.each { |context| context.print_should_eventuallys }
      end

      def build
        shoulds.each do |should|
          create_test_from_should_hash(should)
        end

        subcontexts.each { |context| context.build }

        print_should_eventuallys
      end

      def method_missing(method, *args, &blk)
        test_unit_class.send(method, *args, &blk)
      end

    end
  end
end

module Test # :nodoc: all
  module Unit 
    class TestCase
      extend Thoughtbot::Shoulda
    end
  end
end

