class Creditcard < ActiveRecord::Base 
  before_save :filter_sensitive
  belongs_to :checkout
  belongs_to :address
  has_many :creditcard_payments
  before_validation :prepare

  accepts_nested_attributes_for :address
      
  include ActiveMerchant::Billing::CreditCardMethods

  class ExpiryDate #:nodoc:
    attr_reader :month, :year
    def initialize(month, year)
      @month = month
      @year = year
    end
    
    def expired? #:nodoc:
      Time.now > expiration rescue true
    end
    
    def expiration #:nodoc:
      Time.parse("#{month}/#{month_days}/#{year} 23:59:59") rescue Time.at(0)
    end
    
    private
    def month_days
      mdays = [nil,31,28,31,30,31,30,31,31,30,31,30,31]
      mdays[2] = 29 if Date.leap?(year)
      mdays[month]
    end
  end
  
  def expiry_date
    ExpiryDate.new(Time.now.month, Time.now.year)
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
    !verification_value.blank?
  end

  # Show the card number, with all but last 4 numbers replace with "X". (XXXX-XXXX-XXXX-4338)
  #def display_number
  #  self.class.mask(number)
  #end
  
  def last_digits
    self.class.last_digits(number)
  end

  # needed for some of the ActiveMerchant gateways (eg. Protx)
  def brand
    cc_type
  end 

  def validate 
    validate_essential_attributes
    validate_card_type
    #validate_card_number
    #validate_verification_value 
    #validate_switch_or_solo_attributes
  end
  
  def self.requires_verification_value?
    true
    #require_verification_value
  end
  
  private
  # Validation logic ripped from ActiveMerchant's Creditcard model
  # http://github.com/Shopify/active_merchant/tree/master/lib/active_merchant/billing/credit_card.rb
  def filter_sensitive
    self.display_number = ActiveMerchant::Billing::CreditCard.mask(number) if self.display_number.blank?
    self.number = nil unless Spree::Config[:store_cc]
    self.verification_value = nil unless Spree::Config[:store_cvv]
  end

  def prepare #:nodoc:
    self.month = month.to_i
    self.year = year.to_i
    self.number = number.to_s.gsub(/[^\d]/, "")
    self.cc_type.downcase! if cc_type.respond_to?(:downcase)
    self.cc_type = spree_cc_type if cc_type.blank?    
    self.first_name = address.firstname if address
    self.last_name = address.lastname if address
  end
  
  def validate_card_number #:nodoc:
    errors.add :number, "is not a valid credit card number" unless Creditcard.valid_number?(number)
    unless errors.on(:number) || errors.on(:cc_type)
      errors.add :cc_type, "is not the correct card type" unless Creditcard.matching_type?(number, cc_type)
    end
  end
  
  def validate_card_type #:nodoc:
    #errors.add :cc_type, "is required" if cc_type.blank?
    errors.add :cc_type, "is invalid" unless Creditcard.card_companies.keys.include?(cc_type)
  end
  
  def validate_essential_attributes #:nodoc:
    errors.add :first_name, "cannot be empty" if first_name.blank?
    errors.add :last_name, "cannot be empty" if last_name.blank?
    errors.add :month, "is not a valid month" unless valid_month?(month)
    errors.add :year, "expired" if expired?
    errors.add :year, "is not a valid year" unless valid_expiry_year?(year)
  end
  
  def validate_switch_or_solo_attributes #:nodoc:
    if %w[switch solo].include?(cc_type)
      unless valid_month?(@start_month) && valid_start_year?(@start_year) || valid_issue_number?(@issue_number)
        errors.add :start_month, "is invalid" unless valid_month?(@start_month)
        errors.add :start_year, "is invalid" unless valid_start_year?(@start_year)
        errors.add :issue_number, "cannot be empty" unless valid_issue_number?(@issue_number)
      end
    end
  end
  
  def validate_verification_value #:nodoc:
    if Creditcard.requires_verification_value?
      errors.add :verification_value, "is required" unless verification_value?
    end
  end

end

