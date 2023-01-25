module Spree
  class DataFeedSetting < Base
    belongs_to :store, class_name: 'Spree::Store', foreign_key: 'spree_store_id'

    before_create :generate_uuid

    validates :store, presence: true
    validates :uuid, presence: true, uniqueness: true, on: :update

    def generate_uuid
      write_attribute(:uuid, SecureRandom.uuid)
    end
  end
end
