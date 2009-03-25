module Searchlogic
  module Condition
    class NotLike < Base
      class << self
        def condition_names_for_column
          super + ["not_contain", "not_have"]
        end
      end
      
      def to_conditions(value)
        like = Like.new(klass, options)
        like.value = value
        conditions = like.sanitize
        return conditions if conditions.blank?
        conditions.first.gsub!(" #{like_condition_name} ", " NOT #{like_condition_name} ")
        conditions
      end
    end
  end
end