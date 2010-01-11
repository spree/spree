module Test
  module Unit
    class TestCase
      def stumpdown!
        begin
          if !Stump::Mocks.failures.nil? && !Stump::Mocks.failures.empty?
            fails = Stump::Mocks.failures.map {|object, method| "#{object.inspect} expected #{method}"}.join(", ")
          
            flunk "Unmet expectations: #{fails}"
          end
        ensure
          Stump::Mocks.clear!
        end
      end
      
      def teardown
        stumpdown!
      end
    end
  end
end