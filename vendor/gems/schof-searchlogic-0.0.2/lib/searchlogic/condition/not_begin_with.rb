module Searchlogic
  module Condition
    class NotBeginWith < Base
      class << self
        def condition_names_for_column
          super + ["not_bw", "not_sw", "not_start_with", "not_start", "beginning_is_not", "beginning_not"]
        end
      end
      
      def to_conditions(value)
        begin_with = BeginsWith.new(klass, options)
        begin_with.value = value
        conditions = being_with.sanitize
        return conditions if conditions.blank?
        conditions.first.gsub!(" LIKE ", " NOT LIKE ")
        conditions
      end
    end
  end
end