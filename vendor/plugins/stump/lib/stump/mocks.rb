module Stump
  # A class to track the mocks and proxies that have been satisfied
  class Mocks
    class <<self
      def add(mock)
        @mocks ||= []
        @mocks << mock
      end
      
      def verify(mock)
        @mocks.delete(mock)
      end
      
      def failures
        @mocks
      end
      
      def clear!
        @mocks = []
      end
    end
  end
end