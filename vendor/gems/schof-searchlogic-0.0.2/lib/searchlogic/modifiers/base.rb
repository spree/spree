module Searchlogic
  module Modifiers
    class Base
      class << self
        # A convenience method for the name of this modifier
        def modifier_name
          name.split("::").last.underscore
        end
        
        # The various names for the modifier. The first in the array is the "main" name, the rest are just aliases to the "main" name
        def modifier_names
          [modifier_name]
        end
        
        # The method in the connection adapter that creates the SQL for the modifier
        def adapter_method_name
          "#{modifier_name}_sql"
        end
        
        # The type of value returned from the SQL. A class the extends this MUST define this method.
        def return_type
          raise "You did not specify a return type for the #{modifier_name} modifier. Please specify if it is an :integer, :string, etc."
        end
      end
    end
  end
end