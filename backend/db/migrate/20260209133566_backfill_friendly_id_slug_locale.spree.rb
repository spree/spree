# This migration comes from spree (originally 20230110142344)
class BackfillFriendlyIdSlugLocale < ActiveRecord::Migration[6.1]
  def up
    if Spree::Store.default.present? && Spree::Store.default.default_locale.present?
      FriendlyId::Slug.unscoped.update_all(locale: Spree::Store.default.default_locale)
    end
  end

  def down
    FriendlyId::Slug.unscoped.update_all(locale: nil)
  end
end
