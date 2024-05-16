class BackfillFriendlyIdSlugLocale < ActiveRecord::Migration[6.1]
  def up
    FriendlyId::Slug.unscoped.update_all(locale: Spree::Store.default.default_locale)
  end

  def down
    FriendlyId::Slug.unscoped.update_all(locale: nil)
  end
end
