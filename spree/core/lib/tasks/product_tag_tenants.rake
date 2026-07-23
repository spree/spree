namespace :spree do
  namespace :upgrade do
    desc <<~DESC
      Backfills the +tenant+ column on existing +Spree::Product+ taggings from
      each product's +store_id+, so product tag vocabulary is bounded to the
      owning store (matching +Spree::Order+, which already tenants its taggings).

      Run once after upgrading to the release that adds
      +acts_as_taggable_tenant :store_id+ to +Spree::Product+. New product
      taggings get their tenant automatically; only rows created before the
      upgrade need this. Idempotent — re-running only touches rows still
      missing a tenant.
    DESC
    task backfill_product_tag_tenants: :environment do
      taggings = ActsAsTaggableOn::Tagging.arel_table.name
      products = Spree::Product.table_name

      updated = ActsAsTaggableOn::Tagging.
                where(taggable_type: 'Spree::Product', tenant: nil).
                joins("INNER JOIN #{products} ON #{products}.id = #{taggings}.taggable_id").
                update_all("tenant = #{products}.store_id")

      puts "  Backfilled tenant on #{updated} product tagging(s)."
    end
  end
end
