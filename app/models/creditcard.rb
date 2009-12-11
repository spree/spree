class Creditcard < ActiveRecord::Base 
  # before_save :filter_sensitive 
  belongs_to :checkout
  has_many :creditcard_payments
  
  validates_numericality_of :month, :integer => true
  validates_numericality_of :year, :integer => true   
  validates_presence_of :number
  validates_presence_of :verification_value
  after_validation :remove_sensitive 
  
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
  
  private
  def remove_sensitive
    self.number = nil unless Spree::Config[:store_cc]
    self.verification_value = nil unless Spree::Config[:store_cvv]
  end
  
end

