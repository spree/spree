module ActiveRecord #:nodoc:
  module Reflection #:nodoc:
    
    module ClassMethods #:nodoc:
      
      # Update the default reflection switch so that <tt>:has_many_polymorphs</tt> types get instantiated. 
      # It's not a composed method so we have to override the whole thing.
      def create_reflection(macro, name, options, active_record)
        case macro
          when :has_many, :belongs_to, :has_one, :has_and_belongs_to_many
            klass = options[:through] ? ThroughReflection : AssociationReflection
            reflection = klass.new(macro, name, options, active_record)
          when :composed_of
            reflection = AggregateReflection.new(macro, name, options, active_record)
          # added by has_many_polymorphs #
          when :has_many_polymorphs
            reflection = PolymorphicReflection.new(macro, name, options, active_record)
        end
        write_inheritable_hash :reflections, name => reflection
        reflection
      end
      
    end

    class PolymorphicError < ActiveRecordError #:nodoc:
    end
    
=begin rdoc

The reflection built by the <tt>has_many_polymorphs</tt> method. 

Inherits from ActiveRecord::Reflection::AssociationReflection.

=end

    class PolymorphicReflection < ThroughReflection
      # Stub out the validity check. Has_many_polymorphs checks validity on macro creation, not on reflection.
      def check_validity! 
        # nothing
      end                 

      # Return the source reflection.
      def source_reflection
        # normally is the has_many to the through model, but we return ourselves, 
        # since there isn't a real source class for a polymorphic target
        self
      end      
      
      # Set the classname of the target. Uses the join class name.
      def class_name
        # normally is the classname of the association target
        @class_name ||= options[:join_class_name]
      end
                     
    end
 
  end
end
