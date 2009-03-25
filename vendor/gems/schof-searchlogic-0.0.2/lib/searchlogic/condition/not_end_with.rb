module Searchlogic
  module Condition
    class NotEndWith < Base
      class << self
        def condition_names_for_column
          super + ["not_ew", "not_end", "end_is_not", "end_not"]
        end
      end
      
      def to_conditions(value)
        ends_with = EndsWith.new(klass, options)
        ends_with.value = value
        conditions = ends_with.sanitize
        return conditions if conditions.blank?
        conditions.first.gsub!(" LIKE ", " NOT LIKE ")
        conditions
      end
    end
  end
end