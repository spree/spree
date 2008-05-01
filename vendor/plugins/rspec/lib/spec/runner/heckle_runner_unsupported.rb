module Spec
  module Runner
    # Dummy implementation for Windows that just fails (Heckle is not supported on Windows)
    class HeckleRunner
      def initialize(filter)
        raise "Heckle not supported on Windows"
      end
    end
  end
end
