module Spec
  module Example      
    module Pending
      def pending(message = "TODO")
        if block_given?
          begin
            yield
          rescue Exception => e
            raise Spec::Example::ExamplePendingError.new(message)
          end
          raise Spec::Example::PendingExampleFixedError.new("Expected pending '#{message}' to fail. No Error was raised.")
        else
          raise Spec::Example::ExamplePendingError.new(message)
        end
      end
    end
  end
end
