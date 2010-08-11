class User < ActiveRecord::Base

  has_many :orders
  belongs_to :ship_address, :foreign_key => "ship_address_id", :class_name => "Address"
  belongs_to :bill_address, :foreign_key => "bill_address_id", :class_name => "Address"

  # Include default devise modules. Others available are:
  # :confirmable, :lockable and :timeoutable
  devise :database_authenticatable, :registerable, :token_authenticatable,
         :recoverable, :rememberable, :trackable, :validatable

  # Setup accessible (or protected) attributes for your model
  attr_accessible :email, :password, :password_confirmation, :remember_me
  after_save :ensure_authentication_token!

  # has_role? simply needs to return true or false whether a user has a role or not.
  def has_role?(role_in_question)
    roles.any? { |role| role.name == role_in_question.to_s }
  end

  def self.guest!
    token = User.generate_token(:authentication_token)
    User.create(:email => "#{token}@spree.com", :password => token, :password_confirmation => token)
  end

  def guest?
    self.email.blank?
  end

end
