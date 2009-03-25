module Searchlogic
  module Condition
    class NotNil < Base
      self.value_type = :boolean
      
      class << self
        def condition_names_for_column
          super + ["is_not_nil", "is_not_null", "not_null"]
        end
      end
      
      def to_conditions(value)
        is_nil = Nil.new(klass, options)
        is_nil.value = !value
        is_nil.sanitize
      end
    end
  end
end