class Creditcard < ActiveRecord::Base 
  # before_save :filter_sensitive 
  belongs_to :checkout
  has_many :creditcard_payments
  
  validates_numericality_of :month, :integer => true
  validates_numericality_of :year, :integer => true   
  validates_presence_of :number
  validates_presence_of :verification_value
  
  def name?
    first_name? && last_name?
  end
  
  def first_name?
    !self.first_name.blank?
  end
  
  def last_name?
    !self.last_name.blank?
  end
        
  def name
    "#{self.first_name} #{self.last_name}"
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
  
  def self.requires_verification_value?
    true
    #require_verification_value
  end
  
  
  alias :attributes_with_quotes_default :attributes_with_quotes
  
  private
  # Override default behavior of Rails attr_readonly so that its never written to the database (not even on create)
  def attributes_with_quotes(include_primary_key = true, include_readonly_attributes = true, attribute_names = @attributes.keys)
    attributes_with_quotes_default(include_primary_key, false, attribute_names)
  end

  def remove_readonly_attributes(attributes)
    if self.class.readonly_attributes.present?
      attributes.delete_if { |key, value| self.class.readonly_attributes.include?(key.gsub(/\(.+/,"")) }
    end
    # extra logic for sanitizing the number and verification value based on preferences
    attributes.delete_if { |key, value| key == "number" and !Spree::Config[:store_cc] } 
    attributes.delete_if { |key, value| key == "verification_value" and !Spree::Config[:store_cvv] } 
  end
end

