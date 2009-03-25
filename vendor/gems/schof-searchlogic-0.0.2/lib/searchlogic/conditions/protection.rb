module Searchlogic
  module Conditions
    # = Conditions Protection
    #
    # Adds protection from SQL injections. Just set protect = true and it will limit what kind of conditions it will accept.
    module Protection
      def self.included(klass)
        klass.class_eval do
          attr_reader :protect
          alias_method_chain :conditions=, :protection
        end
      end
      
      def conditions_with_protection=(conditions)
        unless conditions.is_a?(Hash)
          if protect?
            return if conditions.blank?
            raise(ArgumentError, "You can not pass SQL as conditions while the search is being protected, you can only pass a hash")
          end
        end
        
        self.conditions_without_protection = conditions
      end
      
      def protect=(value)
        association_objects.each { |obj| obj.protect = value }
        @protect = value
      end
      
      def protect?
        protect == true
      end
      alias_method :protected?, :protect?
    end
  end
end