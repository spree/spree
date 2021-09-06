module Spree
  class Wishlist < Spree::Base
    include SingleStoreResource

    has_secure_token

    belongs_to :user, class_name: Spree.user_class.to_s
    belongs_to :store, touch: true

    after_commit :ensure_default_exists_and_is_unique

    has_many :wished_variants, dependent: :destroy

    validates :name, :store, :user, presence: true

    def include?(variant_id)
      wished_variants.map(&:variant_id).include? variant_id.to_i
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

    def public?
      !is_private?
    end

    private

    def ensure_default_exists_and_is_unique
      if is_default?
        Wishlist.where(is_default: true, user_id: user_id, store_id: store_id).where.not(id: id).update_all(is_default: false)
      end
    end
  end
end
