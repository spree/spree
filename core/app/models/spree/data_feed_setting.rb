module Spree
  class DataFeedSetting < Base
    belongs_to :store, class_name: 'Spree::Store', foreign_key: 'spree_store_id'

    before_create :generate_uuid

    with_options presence: true do
      validates :store
      validates :uuid, uniqueness: true, on: :update
    end

    def generate_uuid
      write_attribute(:uuid, SecureRandom.uuid)
    end
  end
end
