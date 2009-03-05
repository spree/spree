require 'digest/sha1'
require 'RFC822'
class User < ActiveRecord::Base
  # Virtual attribute for the unencrypted password
  attr_accessor :password

  has_many :addresses, :as => :addressable, :dependent => :destroy
  
  validates_presence_of     :email
  validates_format_of       :email, :with => RFC822::EmailAddress, 
                            :message => 'email must be valid'
  validates_presence_of     :password,                   :if => :password_required?
  validates_presence_of     :password_confirmation,      :if => :password_required?
  validates_length_of       :password, :within => 4..40, :if => :password_required?
  validates_confirmation_of :password,                   :if => :password_required?
  validates_length_of       :email,    :within => 3..100
  validates_uniqueness_of   :email, :case_sensitive => false
  before_save :encrypt_password
  
  has_many :orders
  has_and_belongs_to_many :roles

  # prevents a user from submitting a crafted form that bypasses activation
  # anything else you want your user to change should be added here.
  attr_accessible :email, :password, :password_confirmation

  # has_role? simply needs to return true or false whether a user has a role or not.  
  def has_role?(role_in_question)
    @_list ||= self.roles.collect(&:name)
    (@_list.include?(role_in_question.to_s) )
  end

  # Authenticates a user by their login name and unencrypted password.  Returns the user or nil.
  def self.authenticate(email, password)
    email = "spree@example.com" if email == "admin" # Hack for users who want to type in just admin to this field
    u = find_by_email(email) # need to get the salt
    u && u.authenticated?(password) ? u : nil
  end

  # Encrypts some data with the salt.
  def self.encrypt(password, salt)
    Digest::SHA1.hexdigest("--#{salt}--#{password}--")
  end

  # Encrypts the password with the user salt
  def encrypt(password)
    self.class.encrypt(password, salt)
  end

  def authenticated?(password)
    crypted_password == encrypt(password)
  end

  def remember_token?
    exp_time = ParseDate.parsedate(remember_token_expires_at)
    remember_token_expires_at && Time.now.utc < Time.gm(*exp_time) 
  end

  # These create and unset the fields required for remembering users between browser closes
  def remember_me
    remember_me_for 2.weeks
  end

  def remember_me_for(time)
    remember_me_until time.from_now.utc
  end

  def remember_me_until(time)
    self.remember_token_expires_at = time
    self.remember_token            = encrypt("#{email}--#{remember_token_expires_at}")
    save(false)
  end

  def forget_me
    self.remember_token_expires_at = nil
    self.remember_token            = nil
    save(false)
  end
  
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
  
  def last_address
    addresses.last
  end
  
  protected
    # before filter 
    def encrypt_password
      return if password.blank?
      self.salt = Digest::SHA1.hexdigest("--#{Time.now.to_s}--#{email}--") if new_record?
      self.crypted_password = encrypt(password)
    end
      
    def password_required?
      crypted_password.blank? || !password.blank?
    end
    
    
end
