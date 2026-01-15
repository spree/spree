module Spree
  class CustomerGroup < Spree.base_class
    acts_as_paranoid

    #
    # Associations
    #
    belongs_to :store, class_name: 'Spree::Store', inverse_of: :customer_groups
    has_many :customer_group_users, class_name: 'Spree::CustomerGroupUser', dependent: :destroy
    has_many :users, through: :customer_group_users, source: :user, source_type: Spree.user_class.to_s

    #
    # Validations
    #
    validates :name, presence: true, uniqueness: { scope: [:store_id], conditions: -> { where(deleted_at: nil) } }
    validates :store, presence: true

    #
    # Scopes
    #
    scope :for_store, ->(store) { where(store: store) }

    #
    # Instance Methods
    #
    def users_count
      customer_group_users.count
    end

    # Bulk add customers to the group
    # @param user_ids [Array] array of user IDs to add
    # @return [Integer] number of customers added
    def add_customers(user_ids)
      return 0 if user_ids.blank?

      user_ids = Array(user_ids).map(&:to_s).uniq
      return 0 if user_ids.empty?

      # Get existing user IDs to avoid duplicates
      existing_user_ids = customer_group_users.where(user_id: user_ids).pluck(:user_id).map(&:to_s).to_set

      now = Time.current
      user_type = Spree.user_class.to_s

      records_to_insert = user_ids.filter_map do |user_id|
        next if existing_user_ids.include?(user_id)

        {
          customer_group_id: id,
          user_id: user_id,
          user_type: user_type,
          created_at: now,
          updated_at: now
        }
      end

      return 0 if records_to_insert.empty?

      Spree::CustomerGroupUser.insert_all(records_to_insert)
      added_user_ids = records_to_insert.map { |r| r[:user_id] }
      touch_users(added_user_ids)
      touch

      records_to_insert.size
    end

    # Bulk remove customers from the group
    # @param user_ids [Array] array of user IDs to remove
    # @return [Integer] number of customers removed
    def remove_customers(user_ids)
      return 0 if user_ids.blank?

      user_ids = Array(user_ids).map(&:to_s).uniq
      return 0 if user_ids.empty?

      deleted_count = customer_group_users.where(user_id: user_ids).delete_all

      if deleted_count > 0
        touch_users(user_ids)
        touch
      end

      deleted_count
    end

    private

    def touch_users(user_ids)
      return if user_ids.blank?

      Spree.user_class.where(id: user_ids).touch_all
    end
  end
end
