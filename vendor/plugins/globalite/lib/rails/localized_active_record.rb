module ActiveRecord
  class Errors
    
    # Error messages modified in lang file
    @@default_error_messages.update({
              :inclusion           => :error_message_inclusion.l,
              :exclusion           => :error_message_exclusion.l,
              :invalid             => :error_message_invalid.l,
              :confirmation        => :error_message_confirmation.l,
              :accepted            => :error_message_accepted.l,
              :empty               => :error_message_empty.l,
              :blank               => :error_message_blank.l,
              :too_long            => :error_message_too_long.l,
              :too_short           => :error_message_too_short.l,
              :wrong_length        => :error_message_wrong_length.l,
              :taken               => :error_message_taken.l,
              :not_a_number        => :error_message_not_a_number.l,
            })
    
    # Reloads the localization
    def self.relocalize
      @@default_error_messages.update({
                :inclusion           => :error_message_inclusion.l,
                :exclusion           => :error_message_exclusion.l,
                :invalid             => :error_message_invalid.l,
                :confirmation        => :error_message_confirmation.l,
                :accepted            => :error_message_accepted.l,
                :empty               => :error_message_empty.l,
                :blank               => :error_message_blank.l,
                :too_long            => :error_message_too_long.l,
                :too_short           => :error_message_too_short.l,
                :wrong_length        => :error_message_wrong_length.l,
                :taken               => :error_message_taken.l,
                :not_a_number        => :error_message_not_a_number.l,
              })
    end
    
    # Redefine the ActiveRecord::Errors::full_messages method:
    #  Returns all the full error messages in an array. 'Base' messages are handled as usual.
    #  Non-base messages are prefixed with the attribute name as usual UNLESS they begin with '^'
    #  in which case the attribute name is omitted.
    #  E.g. validates_acceptance_of :accepted_terms, :message => '^Please accept the terms of service'
    #  
    #  
    #  If field name has the same key like in language yaml file, its replaced by its corresponding language file value.
    #  This fixes the problem of translating validation messages but not field names. Now you can fully localize them.
    #  E.g. validates_presence_of :name
    #  produces (in en-UK and pl-PL:
    #  Name can't be empty
    #  Nazwa jest wymagana
    #  By convetion yaml language key falue for field is the same as ActiveRecords model field name
    #  If plugin can't find such key, it behaves just like without plugin.
    def full_messages
      full_messages = []

      @errors.each_key do |attr|
        @errors[attr].each do |msg|
          next if msg.nil?

          if attr == "base"
            full_messages << msg
          elsif msg =~ /^\^/
            full_messages << msg[1..-1]
          else
            full_messages << attr.intern.l(attr).humanize + " " + msg
          end
        end
      end

      return full_messages
    end
    
    # # Handle model error localization
    # def add(attribute, msg = @@default_error_messages[:invalid])
    #        @errors[attribute.l] = [] if @errors[attribute.to_s].nil?
    #        @errors[attribute.l] << msg
    # end
    
  end
end
