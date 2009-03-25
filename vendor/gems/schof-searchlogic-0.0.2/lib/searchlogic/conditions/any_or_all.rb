module Searchlogic
  module Conditions
    # = Any or All
    #
    # Adds the ability to join all conditions wth "AND" or "OR".
    module AnyOrAll
      # Determines if we should join the conditions with "AND" or "OR".
      #
      # === Examples
      #
      #   search.conditions.any = true # will join all conditions with "or", you can also set this to "true", "1", or "yes"
      #   search.conditions.any = false # will join all conditions with "and"
      def any=(value)
        (association_objects + group_objects).each { |object| object.any = value }
        @any = value
      end
      
      def any # :nodoc:
        @any
      end
      
      # Convenience method for determining if we should join the conditions with "AND" or "OR".
      def any?
        ["true", "1", "yes"].include? @any.to_s
      end
      
      # Sets the conditions to be searched by "or"
      def any!
        self.any = true
      end
      
      def all? # :nodoc:
        !any?
      end
      
      # Sets the conditions to be searched by "and"
      def all!
        self.any = false
      end
    end
  end
end