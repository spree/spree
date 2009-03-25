module Searchlogic
  module Condition
    class Keywords < Base
      # Because be default it joins with AND, so padding an array just gives you more options. Joining with and is no different than combining all of the words.
      self.join_arrays_with_or = true
      
      BLACKLISTED_WORDS = ('a'..'z').to_a + ["about", "an", "are", "as", "at", "be", "by", "com", "de", "en", "for", "from", "how", "in", "is", "it", "la", "of", "on", "or", "that", "the", "the", "this", "to", "und", "was", "what", "when", "where", "who", "will", "with", "www"] # from ranks.nl        
      ALLOWED_CHARACTERS = 'àáâãäåßéèêëìíîïñòóôõöùúûüýÿ\-_\.@'
      
      class << self
        def condition_names_for_column
          super + ["kwords", "kw"]
        end
      end
      
      def to_conditions(value)
        strs = []
        subs = []
        
        search_parts = value.to_s.gsub(/,/, " ").split(/ /)
        replace_non_alnum_characters!(search_parts)
        search_parts.uniq!
        remove_blacklisted_words!(search_parts)
        return if search_parts.blank?
        
        search_parts.each do |search_part|
          strs << "#{column_sql} #{like_condition_name} ?"
          subs << "%#{search_part}%"
        end
        
        [strs.join(" AND "), *subs]
      end
      
      private
        def replace_non_alnum_characters!(search_parts)
          search_parts.each do |word|
            word.downcase!
            word.gsub!(/[^[:alnum:]#{ALLOWED_CHARACTERS}]/, '')
          end
        end
        
        def remove_blacklisted_words!(search_parts)
          search_parts.delete_if { |word| word.blank? || BLACKLISTED_WORDS.include?(word.downcase) }
        end
    end
  end
end