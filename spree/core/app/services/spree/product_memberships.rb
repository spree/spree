module Spree
  # Bulk adding and removing products on categories or collections. The
  # including service names the join model (`membership_class`), the grouping
  # it belongs to (`group_class`, `group_key`) and refreshes the grouping's
  # own counters in `refresh_group_counters`.
  module ProductMemberships
    private

    def add_memberships(groups, products)
      group_ids = groups.pluck(:id)
      product_ids = products.pluck(:id)
      # Every group's current size in one grouped count, rather than a probe
      # per group for the position to append at.
      sizes = membership_class.where(group_key => group_ids).group(group_key).count

      rows = group_ids.flat_map do |group_id|
        position = sizes.fetch(group_id, 0)
        product_ids.map do |product_id|
          {
            group_key => group_id, product_id: product_id, position: (position += 1),
            created_at: Time.current, updated_at: Time.current
          }
        end
      end
      membership_class.insert_all(rows)

      refresh_after_membership_change(group_ids, products)
    end

    # Removes the products, then re-packs the remaining positions from 1.
    def remove_memberships(groups, products)
      group_ids = groups.pluck(:id)

      ApplicationRecord.transaction do
        membership_class.where(group_key => group_ids, product_id: products.pluck(:id)).delete_all

        # What survived the delete, for every group in one read.
        remaining = membership_class.where(group_key => group_ids).order(:position).pluck(group_key, :product_id).
                    group_by(&:first).transform_values { |pairs| pairs.map(&:last) }

        rows = group_ids.flat_map do |group_id|
          remaining.fetch(group_id, []).map.with_index(1) do |product_id, position|
            {
              group_key => group_id, product_id: product_id, position: position,
              created_at: Time.current, updated_at: Time.current
            }
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
      Spree::Product.reset_counters_in_bulk(product_ids, membership_class.model_name.element.pluralize.to_sym)
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
