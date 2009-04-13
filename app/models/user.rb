class User < ActiveRecord::Base
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
  
  has_many :orders
  has_and_belongs_to_many :roles
  has_many :addresses
    
  def deliver_password_reset_instructions!
    reset_perishable_token!
    UserMailer.deliver_password_reset_instructions(self)
  end

  # has_role? simply needs to return true or false whether a user has a role or not.  
  def has_role?(role_in_question)
    @_list ||= self.roles.collect(&:name)
    (@_list.include?(role_in_question.to_s) )
  end

=begin
  # -----------------------------------------
  # TODO: Untested with AuthLogic
  # -----------------------------------------
  
  # for anonymous customer support
  def self.generate_login
    record = true
    while record
      login = "anon_" + Array.new(6){rand(6)}.join + "@anon.com"
      record = find(:first, :conditions => ["email = ?", email])
    end
    return login
  end
  
  # I am not sure we want this, but if we do, here is a readymade user for anonymous login  
  def self.anonymous_user
    pw = Digest::SHA1.hexdigest("--#{Time.now.to_s}#{self.object_id}#{Array.new(256){rand(256)}.join}")
    anonymous_user = User.new :password => pw,
                     :password_confirmation => pw,
                     :email => "anon_login_#{Time.now.to_s}@anon.com"
    anonymous_user.roles.push(Role.find_by_name("anonymous").freeze).freeze
  
    # disallow saving the anonymous user by overwriting with singleton save methods
    methods_to_overwrite =
    "save
    save!
    save_with_transactions
    save_with_transactions!
    save_with_validation
    save_with_validation!
    save_without_transactions
    save_without_transactions!
    save_without_validation
    save_without_validation!".split
   
    methods_to_overwrite.each do |method|
      instance_eval("def anonymous_user.#{method}; true; end")
    end
  end
=end
  
  def last_address
    addresses.last
  end    
    
end
