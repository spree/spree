class EnsureStoreDefaultCountryIsSet < ActiveRecord::Migration[5.2]
  def change
    # workaround for missing deleted_at column added in later migrations
    unless Spree::Store.column_names.include?('deleted_at')
      ActiveRecord::Validations::UniquenessParanoiaValidator.module_eval do
        def build_relation(klass, *args)
          super
        end
      end
    end

    Spree::Store.find_each(&:save)
  end
end
