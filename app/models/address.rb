class Address < ActiveRecord::Base
  belongs_to :country
  belongs_to :state

  has_many :billing_checkouts, :foreign_key => "bill_address_id", :class_name => "Checkout"
  has_many :shipping_checkouts, :foreign_key => "ship_address_id", :class_name => "Checkout"
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
  validate :state_in_country

  before_validation :ensure_valid_single_state
  before_save :ensure_valid_single_state

  def checkouts
    (billing_checkouts + shipping_checkouts).uniq
  end

  def self.default
    new :country => Country.find(Spree::Config[:default_country_id])
  end

  # can modify an address if it's not been used in an order (but checkouts controller has finer control)
  def editable?
    new_record? || (shipments.empty? && checkouts.empty?)
  end

  def full_name
    "#{self.firstname} #{self.lastname}".strip
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

  private
    # disconnected since there's no code to display error messages yet OR matching client-side validation
    def phone_validate
      return if phone.blank?
      n_digits = phone.scan(/[0-9]/).size
      valid_chars = (phone =~ /^[-+()\/\s\d]+$/)
      if !(n_digits > 5 && valid_chars)
        errors.add(:phone, :invalid)
      end
    end

    def state_in_country
      country.reload if changes.include?("country_id")

      if state.present? and state.country_id != country_id
        errors.add(:state, :invalid)
      elsif state_name.present? and country.states.present?
        errors.add(:state, :invalid)
      end
    end

    def ensure_valid_single_state
      self.state_name = nil if self.changes.include?("state_id") && self.state_id.present? #clear state_name if state_id is being set

      if self.changes.include?("state_name") && self.state_name.present?
        #check is state_name free text matchs an actual state associated with the country
        country = (country_id ? Country.find(country_id) : nil)

        if country and state = country.states.find(:first, :conditions => ["lower(states.name) = ? or lower(states.abbr) = ?", self.state_name.downcase, self.state_name.downcase])
          self.state      = state #set state to actual associated state
          self.state_name = nil #clear state_name as it's been matched successfully
        else
          self.state      = nil #ensure state_id to nil as state_name is being set
        end
      end

      #fall back to force single state.
      self.state_name = nil if self.state_name.present? && self.state_id.present?

    end
end
