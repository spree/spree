module Spree
  # Bulk adding and removing products on categories or collections. The
  # including service names the join model (`membership_class`), the grouping
  # it belongs to (`group_class`, `group_key`) and refreshes the grouping's
  # own counters in `refresh_group_counters`.
  module ProductMemberships
    private

    def add_memberships(groups, products)
      rows = groups.pluck(:id).flat_map do |group_id|
        position = membership_class.where(group_key => group_id).count
        products.pluck(:id).map do |product_id|
          { group_key => group_id, product_id: product_id, position: (position += 1) }
        end
      end
      membership_class.insert_all(rows)

      refresh_after_membership_change(groups.pluck(:id), products)
    end

    # Removes the products, then re-packs the remaining positions from 1.
    def remove_memberships(groups, products)
      group_ids = groups.pluck(:id)

      ApplicationRecord.transaction do
        membership_class.where(group_key => group_ids, product_id: products.pluck(:id)).delete_all

        rows = group_ids.flat_map do |group_id|
          membership_class.where(group_key => group_id).order(:position).pluck(:product_id).map.with_index(1) do |product_id, position|
            { group_key => group_id, product_id: product_id, position: position }
          end
        end
        membership_class.upsert_all(rows, unique_by: ([group_key, :product_id] unless Spree.mysql?)) if rows.any?
      end

      refresh_after_membership_change(group_ids, products)
    end

    # Bulk writes skip the join model's callbacks, so counters, caches and the
    # search index are refreshed here.
    def refresh_after_membership_change(group_ids, products)
      product_ids = products.pluck(:id)
      product_ids.each { |id| Spree::Product.reset_counters(id, membership_class.model_name.element.pluralize.to_sym) }
      refresh_group_counters(group_ids)

      Spree::Product.where(id: product_ids).touch_all
      products.each(&:enqueue_search_index)
      group_class.where(id: group_ids).touch_all
    end

    def group_key
      group_class.model_name.element.foreign_key.to_sym
    end
  end
end
