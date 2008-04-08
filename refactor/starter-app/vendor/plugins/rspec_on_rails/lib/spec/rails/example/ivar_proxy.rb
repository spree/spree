##
# A wrapper that allows instance variables to be manipulated using +[]+ and
# +[]=+

module Spec
  module Rails
    module Example
      class IvarProxy #:nodoc:

        ##
        # Wraps +object+ allowing its instance variables to be manipulated.

        def initialize(object)
          @object = object
        end

        ##
        # Retrieves +ivar+ from the wrapped object.

        def [](ivar)
          get_variable "@#{ivar}"
        end

        ##
        # Sets +ivar+ to +val+ on the wrapped object.

        def []=(ivar, val)
          set_variable "@#{ivar}", val
        end

        def each
          @object.instance_variables.each do |variable_full_name|
            variable_name = variable_full_name[1...variable_full_name.length]
            yield variable_name, get_variable(variable_full_name)
          end
        end

        def delete(key)
          var_name = "@#{key}"
          if @object.instance_variables.include?(var_name)
            @object.send(:remove_instance_variable, var_name)
          else
            return nil
          end
        end

        def has_key?(key)
          @object.instance_variables.include?("@#{key}")
        end

        protected
        def get_variable(name)
          @object.instance_variable_get name
        end

        def set_variable(name, value)
          @object.instance_variable_set name, value
        end
      end
    end
  end
end
