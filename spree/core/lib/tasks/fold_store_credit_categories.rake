namespace :spree do
  namespace :upgrade do
    desc <<~DESC
      Copies each store credit's legacy category name into its memo
      (Spree 6.0). Store credits no longer carry a category — the reason a
      credit exists is its originator (return, exchange, claim, gift card)
      plus the free-text memo — so this keeps the only information a
      category row held visible in the dashboard once the column and table
      are dropped in 6.1.

      Only credits with a blank memo are touched, so nothing an admin wrote
      is overwritten. Idempotent — a credit whose memo is already filled is
      skipped, and installs without the legacy tables are a no-op.
    DESC
    task fold_store_credit_categories: :environment do
      connection = ActiveRecord::Base.connection
      credits = Spree::StoreCredit.table_name
      categories = 'spree_store_credit_categories'

      unless connection.table_exists?(categories) && connection.column_exists?(credits, :category_id)
        puts '  Legacy store credit categories are gone — nothing to fold.'
        next
      end

      legacy_category = Class.new(ActiveRecord::Base) { self.table_name = 'spree_store_credit_categories' }
      folded = 0

      legacy_category.pluck(:id, :name).each do |category_id, name|
        next if name.blank?

        folded += Spree::StoreCredit.unscoped
                                    .where(category_id: category_id)
                                    .where(memo: [nil, ''])
                                    .update_all(memo: name)
      end

      puts "  Copied the category name into the memo of #{folded} store credit(s)."
    end
  end
end
