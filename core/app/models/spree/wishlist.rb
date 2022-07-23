module Spree
  class Wishlist < Spree::Base
    include SingleStoreResource
    if defined?(Spree::Webhooks)
      include Spree::Webhooks::HasWebhooks
    end

    has_secure_token

    belongs_to :user, class_name: "::#{Spree.user_class}", touch: true
    belongs_to :store, class_name: 'Spree::Store'

    has_many :wished_items, class_name: 'Spree::WishedItem', dependent: :destroy

    after_commit :ensure_default_exists_and_is_unique
    validates :name, :store, :user, presence: true

    def include?(variant_id)
      wished_items.exists?(variant_id: variant_id)
    end

    def to_param
      token
    end

    def self.get_by_param(param)
      find_by(token: param)
    end

    private

    def ensure_default_exists_and_is_unique
      if is_default?
        Wishlist.where(is_default: true, user_id: user_id, store_id: store_id).where.not(id: id).update_all(is_default: false)
      end
    end
  end
end
