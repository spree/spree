module Spree
  class Wishlist < Spree.base_class
    include Spree::SingleStoreResource

    publishes_lifecycle_events

    if Rails::VERSION::STRING >= '7.1.0'
      has_secure_token on: :save
    else
      has_secure_token
    end

    belongs_to :user, class_name: "::#{Spree.user_class}", touch: true
    belongs_to :store, class_name: 'Spree::Store'

    has_many :wished_items, class_name: 'Spree::WishedItem', dependent: :destroy
    has_many :variants, through: :wished_items, source: :variant, class_name: 'Spree::Variant'
    has_many :products, -> { distinct }, through: :variants, source: :product, class_name: 'Spree::Product'

    after_commit :ensure_default_exists_and_is_unique
    validates :name, :store, :user, presence: true

    def include?(variant_id)
      wished_items.exists?(variant_id: variant_id)
    end

    def to_param
      token
    end

    # returns the number of wished items in the wishlist
    #
    # @return [Integer]
    def wished_items_count
      @wished_items_count ||= variant_ids.count
    end

    # returns the variant ids in the wishlist
    #
    # @return [Array<Integer>]
    def variant_ids
      @variant_ids ||= wished_items.pluck(:variant_id)
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
