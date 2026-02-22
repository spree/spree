class Spree::User < Spree.base_class
    # Spree modules
    include Spree::UserAddress
    include Spree::UserMethods
    include Spree::UserPaymentSource
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
end
