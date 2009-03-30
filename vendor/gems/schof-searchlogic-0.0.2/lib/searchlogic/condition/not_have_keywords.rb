module Searchlogic
  module Condition
    class NotHaveKeywords < Base
      class << self
        def condition_names_for_column
          super + ["not_have_keywords", "not_keywords", "not_have_kw", "not_kw", "not_have_kwwords", "not_kwwords"]
        end
      end
      
      def to_conditions(value)
        keywords = Keywords.new(klass, options)
        keywords.value = value
        conditions = keywords.sanitize
        return conditions if conditions.blank?
        conditions.first.gsub!(" #{like_condition_name} ", " NOT #{like_condition_name} ")
        conditions
      end
    end
  end
end