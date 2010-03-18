class Address < ActiveRecord::Base
  belongs_to :country
  belongs_to :state

  has_many :checkouts, :foreign_key => "bill_address_id"
  has_many :shipments

  validates_presence_of :firstname
  validates_presence_of :lastname
  validates_presence_of :address1
  validates_presence_of :city
  validates_presence_of :state, :if => Proc.new { |address| address.state_name.blank? && Spree::Config[:address_requires_state] }
  validates_presence_of :state_name, :if => Proc.new { |address| address.state.blank? && Spree::Config[:address_requires_state] }
  validates_presence_of :zipcode
  validates_presence_of :country
  validates_presence_of :phone
  validate :state_name_validate, :if => Proc.new { |address| address.state.blank? && Spree::Config[:address_requires_state] }

  # disconnected since there's no code to display error messages yet OR matching client-side validation
  def phone_validate
    return if phone.blank?
    n_digits = phone.scan(/[0-9]/).size
    valid_chars = (phone =~ /^[-+()\/\s\d]+$/)
    if !(n_digits > 5 && valid_chars)
      errors.add(:phone, :invalid)
    end
  end

  def state_name_validate
    country = country_id ? Country.find(country_id) : nil
    return if country.blank? || country.states.empty?
    if state_name.blank? || country.states.name_or_abbr_equals(state_name).empty?
      errors.add(:state, :invalid)
    end
  end

  def self.default
    new :country => Country.find(Spree::Config[:default_country_id])
  end

  # can modify an address if it's not been used in an order (but checkouts controller has finer control)
  def editable?
    new_record? || (shipments.empty? && checkouts.empty?)
  end

  def full_name
    self.firstname + " " + self.lastname
  end

  def state_text
    state.nil? ? state_name : (state.abbr.blank? ? state.name : state.abbr)
  end

  def zone
    (state && state.zone) ||
    (country && country.zone)
  end

  def zones
    Zone.match(self)
  end

  def same_as?(other)
    return false if other.nil?
    attributes.except("id", "updated_at", "created_at") ==  other.attributes.except("id", "updated_at", "created_at")
  end
  alias same_as same_as?

  def to_s
    "#{full_name}: #{address1}"
  end

  def clone
    Address.new(self.attributes.except("id", "updated_at", "created_at"))
  end

  def ==(other_address)
    self_attrs = self.attributes
    other_attrs = other_address.respond_to?(:attributes) ? other_address.attributes : {}

    [self_attrs, other_attrs].each { |attrs| attrs.except!("id", "created_at", "updated_at", "order_id") }

    self_attrs == other_attrs
  end

  def empty?
    attributes.except("id", "created_at", "updated_at", "order_id", "country_id").all? {|k,v| v.nil?}
  end
end
