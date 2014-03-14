class MigrateOldPreferences < ActiveRecord::Migration
  def up
    migrate_preferences(Spree::Calculator)
    migrate_preferences(Spree::PaymentMethod)
    migrate_preferences(Spree::PromotionRule)
  end

  def down
  end

  private
  def migrate_preferences klass
    klass.reset_column_information
    klass.find_each do |record|
      store = Spree::Preferences::ScopedStore.new(record.class.name.underscore, record.id)
      record.defined_preferences.each do |key|
        value = store.fetch(key){}
        record.preferences[key] = value unless value.nil?
      end
      record.save!
    end
  end
end
