module Spree
  class CustomerGroup < Spree.base_class
    has_prefix_id :cg

    acts_as_paranoid

    include Spree::SingleStoreResource
    search_by :name

    #
    # Associations
    #
    belongs_to :store, class_name: 'Spree::Store', inverse_of: :customer_groups
    has_many :customer_group_users, class_name: 'Spree::CustomerGroupUser', dependent: :destroy
    has_many :users, through: :customer_group_users, source: :customer,
                     source_type: Spree.customer_class.to_s, deprecated: true
    has_many :catalog_assignments, as: :assignable, class_name: 'Spree::CatalogAssignment',
                                   dependent: :destroy
    has_many :catalogs, through: :catalog_assignments, class_name: 'Spree::Catalog'
    # `customers` is the public name across the v3 API; declaring it as its
    # own association (rather than `alias_method`) is what lets `customer_ids=`
    # exist and what makes the `PrefixedId` auto-decoder in `assign_attributes`
    # recognise the key — that lookup keys off `reflect_on_association(:customers)`.
    # Joining a group changes nothing on the customer, so saving the group
    # does not re-validate every member it lists.
    has_many :customers, through: :customer_group_users, source: :customer, source_type: Spree.customer_class.to_s,
                         validate: false

    #
    # Validations
    #
    validates :name, presence: true, uniqueness: { scope: [:store_id], conditions: -> { where(deleted_at: nil) } }

    #
    # Instance Methods
    #
    # FIXME: convert this to counter cache
    def customers_count
      customer_group_users.size
    end
    alias_method :users_count, :customers_count

    # Bulk add customers to the group
    # @param user_ids [Array] array of user IDs to add
    # @return [Integer] number of customers added
    def add_customers(user_ids)
      self.class.add_customers_to([self], user_ids)
    end

    # Bulk remove customers from the group
    # @param user_ids [Array] array of user IDs to remove
    # @return [Integer] number of customers removed
    def remove_customers(user_ids)
      self.class.remove_customers_from([self], user_ids)
    end

    # Adds customers to every given group, skipping memberships that already
    # exist, with one lookup for all groups.
    # @param groups [Array<Spree::CustomerGroup>]
    # @param customer_ids [Array] customer IDs to add
    # @return [Integer] number of memberships created
    def self.add_customers_to(groups, customer_ids)
      customer_ids = Array(customer_ids).compact_blank.map(&:to_s).uniq
      groups = Array(groups)
      return 0 if customer_ids.empty? || groups.empty?

      existing_pairs = Spree::CustomerGroupUser.
                       where(customer_group_id: groups.map(&:id), customer_id: customer_ids).
                       pluck(:customer_group_id, :customer_id).
                       to_set { |group_id, customer_id| [group_id, customer_id.to_s] }

      now = Time.current
      customer_type = Spree.customer_class.to_s
      records_to_insert = groups.flat_map do |group|
        customer_ids.filter_map do |customer_id|
          next if existing_pairs.include?([group.id, customer_id])

          {
            customer_group_id: group.id,
            customer_id: customer_id,
            customer_type: customer_type,
            created_at: now,
            updated_at: now
          }
        end
      end
      return 0 if records_to_insert.empty?

      Spree::CustomerGroupUser.upsert_all(records_to_insert, on_duplicate: :skip)
      touch_customers(records_to_insert.map { |record| record[:customer_id] }.uniq)
      changed_group_ids = records_to_insert.map { |record| record[:customer_group_id] }.to_set
      groups.select { |group| changed_group_ids.include?(group.id) }.each(&:touch)

      records_to_insert.size
    end

    # Removes customers from every given group.
    # @param groups [Array<Spree::CustomerGroup>]
    # @param customer_ids [Array] customer IDs to remove
    # @return [Integer] number of memberships removed
    def self.remove_customers_from(groups, customer_ids)
      customer_ids = Array(customer_ids).compact_blank.map(&:to_s).uniq
      groups = Array(groups)
      return 0 if customer_ids.empty? || groups.empty?

      memberships = Spree::CustomerGroupUser.where(customer_group_id: groups.map(&:id), customer_id: customer_ids)
      changed_group_ids = memberships.distinct.pluck(:customer_group_id).to_set
      return 0 if changed_group_ids.empty?

      deleted_count = memberships.delete_all
      touch_customers(customer_ids)
      groups.select { |group| changed_group_ids.include?(group.id) }.each(&:touch)

      deleted_count
    end

    def self.touch_customers(customer_ids)
      Spree.customer_class.where(id: customer_ids).touch_all
    end
    private_class_method :touch_customers
  end
end
