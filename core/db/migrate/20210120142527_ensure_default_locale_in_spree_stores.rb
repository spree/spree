class EnsureDefaultLocaleInSpreeStores < ActiveRecord::Migration[5.2]
  def change
    Spree::Store.where(default_locale: nil).update_all(default_locale: I18n.locale)
  end
end
