namespace :spree do
  namespace :upgrade do
    desc <<~DESC
      Stamps the store on taggings written without one, for every taggable
      that keeps its taggings per store. Tags added through the bulk endpoints
      before Spree 6.0 carried no store, and the admin tag list filters by it,
      so those tags were missing from the list. Idempotent — taggings that
      already carry a store are skipped.
    DESC
    task backfill_tagging_tenants: :environment do
      total = 0

      Spree.taggable_types.map(&:constantize).each do |taggable|
        column = taggable.try(:tenant_column)
        next if column.blank?

        count = 0
        ActsAsTaggableOn::Tagging.where(taggable_type: taggable.polymorphic_name, tenant: nil).in_batches do |taggings|
          tenants = taggable.unscoped.where(id: taggings.select(:taggable_id)).pluck(:id, column).to_h

          tenants.compact.group_by { |_id, tenant| tenant }.each do |tenant, pairs|
            count += taggings.where(taggable_id: pairs.map(&:first)).update_all(tenant: tenant.to_s)
          end
        end

        next if count.zero?

        total += count
        puts "  #{taggable.name}: #{count} tagging(s) stamped with the #{column}."
      end

      puts total.zero? ? '  Nothing to backfill.' : "  Backfilled #{total} tagging(s)."
    end
  end
end
