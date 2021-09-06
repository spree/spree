module Spree
  class Wishlist < Spree::Base
    include SingleStoreResource

    has_secure_token

    belongs_to :user, class_name: Spree.user_class.to_s
    belongs_to :store, touch: true

    has_many :wished_products, dependent: :destroy

    validates :name, presence: true

    def include?(variant_id)
      wished_products.map(&:variant_id).include? variant_id.to_i
    end

    def to_param
      token
    end

    def self.get_by_param(param)
      find_by_token(param)
    end

    def can_be_read_by?(user)
      public? || user == self.user
    end

    def is_default=(value)
      self[:is_default] = value
      return unless is_default?

      Spree::Wishlist.where(is_default: true, user_id: user_id).where.not(id: id).update_all(is_default: false)
    end

    def public?
      !is_private?
    end
  end
end
