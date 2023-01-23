module Spree
  class GoogleFeedSetting < Base
    belongs_to :store, class_name: 'Spree::Store', foreign_key: 'spree_store_id'

    validates :store, presence: true
    validates :uuid, presence: true

    before_create :generate_uuid

    def enabled_keys
      keys = []

      attributes.each do |key, value|
        if value == true
          keys.append(key.to_sym)
        end
      end

      keys
    end

    def generate_uuid
      write_attribute(:uuid, SecureRandom.uuid)
    end
  end
end
