module Spree #:nodoc:
  module Support #:nodoc:
    module CoreExtensions #:nodoc:
      module String 

        def is_integer?
          begin
            Integer(self.to_s)
            return true
          rescue ArgumentError
            return false
          end
        end

      end
    end
  end
end