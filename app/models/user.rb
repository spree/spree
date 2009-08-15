class User < ActiveRecord::Base           
  before_validation :set_login  
  before_save :add_user_role

  has_many :orders
  has_and_belongs_to_many :roles

  belongs_to :ship_address, :foreign_key => "ship_address_id", :class_name => "Address"
  belongs_to :bill_address, :foreign_key => "bill_address_id", :class_name => "Address"

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

  # prevents a user from submitting a crafted form that bypasses activation
  # anything else you want your user to change should be added here.
  attr_accessible :email, :password, :password_confirmation

  def deliver_password_reset_instructions!
    reset_perishable_token!
    UserMailer.deliver_password_reset_instructions(self)
  end

  # has_role? simply needs to return true or false whether a user has a role or not.  
  def has_role?(role_in_question)
    @_list ||= self.roles.collect(&:name)
    (@_list.include?(role_in_question.to_s) )
  end
  
  private 
  def set_login
    # for now force login to be same as email, eventually we will make this configurable, etc.
    self.login = email
  end 
  
  def add_user_role
    user_role = Role.find_by_name("user")
    self.roles << user_role if user_role and self.roles.empty?
  end     
end
