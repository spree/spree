if defined?(ActiveRecord::Base)
  module ActiveRecord #:nodoc:
    class Base

      (class << self; self; end).class_eval do
        # Extension for <tt>should have</tt> on AR Model classes
        #
        #   ModelClass.should have(:no).records
        #   ModelClass.should have(1).record
        #   ModelClass.should have(n).records
        def records
          find(:all)
        end
        alias :record :records
      end

      # Extension for <tt>should have</tt> on AR Model instances
      #
      #   model.should have(:no).errors_on(:attribute)
      #   model.should have(1).error_on(:attribute)
      #   model.should have(n).errors_on(:attribute)
      def errors_on(attribute)
        self.valid?
        [self.errors.on(attribute)].flatten.compact
      end
      alias :error_on :errors_on

    end
  end
end