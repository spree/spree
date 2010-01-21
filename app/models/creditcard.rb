class Creditcard < ActiveRecord::Base         
  belongs_to :checkout
  has_many :creditcard_payments
  has_many :creditcard_txns
  alias :txns :creditcard_txns
  
  before_save :set_last_digits
  
  validates_numericality_of :month, :integer => true
  validates_numericality_of :year, :integer => true   
  validates_presence_of :number, :unless => :has_payment_profile?, :on => :create
  validates_presence_of :verification_value, :unless => :has_payment_profile?, :on => :create
  
  def has_payment_profile?
    gateway_customer_profile_id.present?
  end
  
  def set_last_digits
    self.last_digits ||= number.to_s.length <= 4 ? number : number.to_s.slice(-4..-1) 
  end
    
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
  def display_number
   "XXXX-XXXX-XXXX-#{last_digits}"
  end
  
  alias :attributes_with_quotes_default :attributes_with_quotes
  
  def authorization
    #find the transaction associated with the original authorization/capture
    txns.find(:first,
              :conditions => ["txn_type = ? AND response_code IS NOT NULL", CreditcardTxn::TxnType::AUTHORIZE.to_s],
              :order => 'created_at DESC')
  end

  def can_capture?
    authorization && txns.count(:conditions => {:txn_type => CreditcardTxn::TxnType::CAPTURE}) == 0
  end
  
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

