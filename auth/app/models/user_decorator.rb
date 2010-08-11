User.class_eval do
  #alias_attribute :token, :api_key
  #before_validation :generate_token
  #validates_presence_of :token

  # Include default devise modules. Others available are:
  # :confirmable, :lockable and :timeoutable
  devise :database_authenticatable, :registerable, :token_authenticatable,
         :recoverable, :rememberable, :trackable, :validatable

  # Setup accessible (or protected) attributes for your model
  attr_accessible :email, :password, :password_confirmation, :remember_me

  # def generate_token
  #   self.token ||= secure_digest(Time.now, (1..10).map{ rand.to_s })
  # end
  #
  # def regenerate_token!
  #   self.update_attribute(:api_key, secure_digest(Time.now, (1..10).map{ rand.to_s }))
  # end
  #
  # private
  # def secure_digest(*args)
  #   Digest::SHA1.hexdigest(args.flatten.join('--'))
  # end
end