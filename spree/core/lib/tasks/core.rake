require 'active_record'

namespace :db do
  task migrate_admin_users_to_role_users: :environment do |_t, _args|
    default_store = Spree::Store.default
    Spree::RoleUser.where(resource: nil).each do |role_user|
      role_user.update_columns(resource_type: default_store.class.name, resource_id: default_store.id)
    end
  end

end

namespace :core do
  desc 'Set "active" status on draft products where make_active_at is in the past'
  task activate_products: :environment do |_t, _args|
    Spree::Product.where('make_active_at <= ?', Time.current).where(status: 'draft').update_all(status: 'active', updated_at: Time.current)
  end

  desc 'Set "archived" status on active products where discontinue_on is in the past'
  task archive_products: :environment do |_t, _args|
    Spree::Product.where('discontinue_on <= ?', Time.current).where.not(status: 'archived').update_all(status: 'archived', updated_at: Time.current)
  end

  desc 'Migrate amount spree_prices.compare_at_amount.'
  task migrate_compare_at_amount: :environment do |_t, _args|
    include ActionView::Helpers::TextHelper
    puts '... started'
    total = 0
    Spree::Price.where(compare_at_amount: 0).in_batches do |prices|
      prices.update_all(compare_at_amount: nil)
      total += prices.count
    end
    puts '... done'
    puts "... migrated #{pluralize(total, 'record')}"
  end

  desc 'Migrate newsletter subscribers'
  task migrate_newsletter_subscribers: :environment do |_t, _args|
    Spree.user_class.where(accepts_email_marketing: true).in_batches(of: 500) do |user_batch|
      subscriber_attributes = user_batch.pluck(:id, :email, :updated_at).map do |id, email, updated_at|
        {
          email: Spree::NewsletterSubscriber.new(email: email).email, # normalized email
          user_id: id,
          verified_at: updated_at,
          verification_token: nil,
          updated_at: DateTime.current,
          created_at: DateTime.current
        }
      end

      Spree::NewsletterSubscriber.insert_all(subscriber_attributes.uniq { |attrs| attrs[:email] })
    end
  end
end
