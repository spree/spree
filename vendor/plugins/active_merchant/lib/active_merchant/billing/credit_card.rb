require 'time'
require 'date'
require 'active_merchant/billing/expiry_date'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # == Description
    # This credit card object can be used as a stand alone object. It acts just like an ActiveRecord object
    # but doesn't support the .save method as its not backed by a database.
    # 
    # For testing purposes, use the 'bogus' credit card type. This card skips the vast majority of 
    # validations. This allows you to focus on your core concerns until you're ready to be more concerned 
    # with the details of particular creditcards or your gateway.
    # 
    # == Testing With CreditCard
    # Often when testing we don't care about the particulars of a given card type. When using the 'test' 
    # mode in your Gateway, there are six different valid card numbers: 1, 2, 3, 'success', 'fail', 
    # and 'error'.
    # 
    #--
    # For details, see CreditCardMethods#valid_number?
    #++
    # 
    # == Example Usage
    #   cc = CreditCard.new(
    #     :first_name => 'Steve', 
    #     :last_name  => 'Smith', 
    #     :month      => '9', 
    #     :year       => '2010', 
    #     :type       => 'visa', 
    #     :number     => '4242424242424242'
    #   )
    #   
    #   cc.valid? # => true
    #   cc.display_number # => XXXX-XXXX-XXXX-4242
    #
    class CreditCard
      include CreditCardMethods
      include Validateable
      
      ## Attributes
      
      cattr_accessor :require_verification_value
      self.require_verification_value = true
      
      # Essential attributes for a valid, non-bogus creditcards
      attr_accessor :number, :month, :year, :type, :first_name, :last_name
      
      # Required for Switch / Solo cards
      attr_accessor :start_month, :start_year, :issue_number

      # Optional verification_value (CVV, CVV2 etc). Gateways will try their best to 
      # run validation on the passed in value if it is supplied
      attr_accessor :verification_value

      # Provides proxy access to an expiry date object
      def expiry_date
        ExpiryDate.new(@month, @year)
      end

      def expired?
        expiry_date.expired?
      end
      
      def name?
        first_name? && last_name?
      end
      
      def first_name?
        !@first_name.blank?
      end
      
      def last_name?
        !@last_name.blank?
      end
            
      def name
        "#{@first_name} #{@last_name}"
      end
            
      def verification_value?
        !@verification_value.blank?
      end

      # Show the card number, with all but last 4 numbers replace with "X". (XXXX-XXXX-XXXX-4338)
      def display_number
        self.class.mask(number)
      end
      
      def last_digits
        self.class.last_digits(number)
      end
      
      def validate
        validate_essential_attributes

        # Bogus card is pretty much for testing purposes. Lets just skip these extra tests if its used
        return if type == 'bogus'

        validate_card_type
        validate_card_number
        validate_verification_value
        validate_switch_or_solo_attributes
      end
      
      def self.requires_verification_value?
        require_verification_value
      end
      
      private
      
      def before_validate #:nodoc: 
        self.month = month.to_i
        self.year  = year.to_i
        self.number = number.to_s.gsub(/[^\d]/, "")
        self.type.downcase! if type.respond_to?(:downcase)
        self.type = self.class.type?(number) if type.blank?
      end
      
      def validate_card_number #:nodoc:
        errors.add :number, "is not a valid credit card number" unless CreditCard.valid_number?(number)
        unless errors.on(:number) || errors.on(:type)
          errors.add :type, "is not the correct card type" unless CreditCard.matching_type?(number, type)
        end
      end
      
      def validate_card_type #:nodoc:
        errors.add :type, "is required" if type.blank?
        errors.add :type, "is invalid"  unless CreditCard.card_companies.keys.include?(type)
      end
      
      def validate_essential_attributes #:nodoc:
        errors.add :first_name, "cannot be empty"      if @first_name.blank?
        errors.add :last_name,  "cannot be empty"      if @last_name.blank?
        errors.add :month,      "is not a valid month" unless valid_month?(@month)
        errors.add :year,       "expired"              if expired?
        errors.add :year,       "is not a valid year"  unless valid_expiry_year?(@year)
      end
      
      def validate_switch_or_solo_attributes #:nodoc:
        if %w[switch solo].include?(type)
          unless valid_month?(@start_month) && valid_start_year?(@start_year) || valid_issue_number?(@issue_number)
            errors.add :start_month,  "is invalid"      unless valid_month?(@start_month)
            errors.add :start_year,   "is invalid"      unless valid_start_year?(@start_year)
            errors.add :issue_number, "cannot be empty" unless valid_issue_number?(@issue_number)
          end
        end
      end
      
      def validate_verification_value #:nodoc:
        if CreditCard.requires_verification_value?
          errors.add :verification_value, "is required" unless verification_value? 
        end
      end
    end
  end
end
