class Spree::AdminUser < Spree.base_class
    # Spree modules
    include Spree::AdminUserMethods
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
end
