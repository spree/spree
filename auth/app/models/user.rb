class User < ActiveRecord::Base

  has_many :orders
  has_and_belongs_to_many :roles
  belongs_to :ship_address, :foreign_key => "ship_address_id", :class_name => "Address"
  belongs_to :bill_address, :foreign_key => "bill_address_id", :class_name => "Address"

  before_save :check_admin
  before_validation :set_login

  acts_as_authentic do |c|
    c.transition_from_restful_authentication = true
    #AuthLogic defaults
    #c.validate_email_field = true
    #c.validates_length_of_email_field_options = {:within => 6..100}
    #c.validates_format_of_email_field_options = {:with => email_regex, :message => I18n.t(‘error_messages.email_invalid’, :default => “should look like an email address.”)}
    #c.validate_password_field = true
    #c.validates_length_of_password_field_options = {:minimum => 4, :if => :require_password?}
    #for more defaults check the AuthLogic documentation
  end

  # Setup accessible (or protected) attributes for your model
  attr_accessible :email, :password, :password_confirmation, :remember_me, :anonymous

  alias_attribute :token, :persistence_token

  # has_role? simply needs to return true or false whether a user has a role or not.
  def has_role?(role_in_question)
    roles.any? { |role| role.name == role_in_question.to_s }
  end

  def self.anonymous!
    token = User.generate_token(:persistence_token)
    User.create(:email => "#{token}@example.com", :password => token, :password_confirmation => token, :anonymous => true)
  end

  def email=(email)
    self.anonymous = false unless email.include?("example.com")
    write_attribute :email, email
  end

  def self.admin_created?
    Role.find_by_name('admin').users.count > 0
  end

  def deliver_password_reset_instructions!
    reset_perishable_token!
    UserMailer.password_reset_instructions(self).deliver
  end

  private

  def check_admin
    unless self.class.admin_created?
      self.roles << Role.find_by_name("admin")
    end
    true
  end

  def set_login
    # for now force login to be same as email, eventually we will make this configurable, etc.
    self.login ||= self.email if self.email
  end 

  # Generate a friendly string randomically to be used as token.
  def self.friendly_token
    ActiveSupport::SecureRandom.base64(15).tr('+/=', '-_ ').strip.delete("\n")
  end

  # Generate a token by looping and ensuring does not already exist.
  def self.generate_token(column)
    loop do
      token = friendly_token
      break token unless find(:first, :conditions => { column => token })
    end
  end

end
