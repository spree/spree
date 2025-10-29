require 'active_record'

namespace :db do
  desc %q{Loads a specified fixture file:
use rake db:load_file[/absolute/path/to/sample/filename.rb]}

  task :load_file, [:file, :dir] => :environment do |_t, args|
    file = Pathname.new(args.file)

    puts "loading ruby #{file}"
    load file
  end

  desc 'Loads fixtures from the the dir you specify using rake db:load_dir[loadfrom]'
  task :load_dir, [:dir] => :environment do |_t, args|
    dir = args.dir
    dir = File.join(Rails.root, 'db', dir) if Pathname.new(dir).relative?

    ruby_files = {}
    Dir.glob(File.join(dir, '**/*.{rb}')).each do |fixture_file|
      ext = File.extname fixture_file
      ruby_files[File.basename(fixture_file, '.*')] = fixture_file
    end
    ruby_files.sort.each do |fixture, ruby_file|
      # If file exists within application it takes precedence.
      if File.exist?(File.join(Rails.root, 'db/default/spree', "#{fixture}.rb"))
        ruby_file = File.expand_path(File.join(Rails.root, 'db/default/spree', "#{fixture}.rb"))
      end
      # an invoke will only execute the task once
      Rake::Task['db:load_file'].execute(Rake::TaskArguments.new([:file], [ruby_file]))
    end
  end

  desc 'Migrate schema to version 0 and back up again. WARNING: Destroys all data in tables!!'
  task remigrate: :environment do
    require 'highline/import'

    if ENV['SKIP_NAG'] || ENV['OVERWRITE'].to_s.casecmp('true').zero? || agree("This task will destroy any data in the database. Are you sure you want to \ncontinue? [y/n] ")

      # Drop all tables
      ActiveRecord::Base.connection.tables.each { |t| ActiveRecord::Base.connection.drop_table t }

      # Migrate upward
      Rake::Task['db:migrate'].invoke

      # Dump the schema
      Rake::Task['db:schema:dump'].invoke
    else
      say 'Task cancelled.'
      exit
    end
  end

  desc 'Bootstrap is: migrating, loading defaults, sample data and seeding (for all extensions) and load_products tasks'
  task :bootstrap do
    require 'highline/import'

    # remigrate unless production mode (as safety check)
    if %w[demo development test].include? Rails.env
      if ENV['AUTO_ACCEPT'] || agree("This task will destroy any data in the database. Are you sure you want to \ncontinue? [y/n] ")
        ENV['SKIP_NAG'] = 'yes'
        Rake::Task['db:create'].invoke
        Rake::Task['db:remigrate'].invoke
      else
        say 'Task cancelled, exiting.'
        exit
      end
    else
      say 'NOTE: Bootstrap in production mode will not drop database before migration'
      Rake::Task['db:migrate'].invoke
    end

    ActiveRecord::Base.send(:subclasses).each(&:reset_column_information)

    load_defaults = Spree::Country.count == 0
    load_defaults ||= agree('Countries present, load sample data anyways? [y/n]: ')
    Rake::Task['db:seed'].invoke if load_defaults

    if Rails.env.production? && Spree::Product.count > 0
      load_sample = agree('WARNING: In Production and products exist in database, load sample data anyways? [y/n]:')
    else
      load_sample = true if ENV['AUTO_ACCEPT']
      load_sample ||= agree('Load Sample Data? [y/n]: ')
    end

    if load_sample
      # Reload models' attributes in case they were loaded in old migrations with wrong attributes
      ActiveRecord::Base.descendants.each(&:reset_column_information)
      Rake::Task['spree_sample:load'].invoke
    end

    puts "Bootstrap Complete.\n\n"
  end

  desc 'Fix orphan line items after upgrading to Spree 3.1: only needed if you have line items attached to deleted records with Slug (product) and SKU (variant) duplicates of non-deleted records.'
  task fix_orphan_line_items: :environment do |_t, _args|
    def get_input
      STDOUT.flush
      input = STDIN.gets.chomp
      case input.upcase
      when 'Y'
        return true

      when 'N'
        puts 'aborting .....'
        return false
      else
        return true
      end
    end

    puts 'WARNING: This task will re-associate any line_items associated with deleted variants to non-deleted variants with matching SKUs. Because other attributes and product associations may switch during the re-association, this may have unintended side-effects. If this task finishes successfully, line items for old order should no longer be orphaned from their variants. You should run this task after you have already run the db migratoin AddDiscontinuedToProductsAndVariants. If the db migration did not warn you that it was leaving deleted records in place because of duplicate SKUs, then you do not need to run this rake task.'
    puts 'Are you sure you want to continue? (Y/n):'

    if get_input
      puts 'looping through all your deleted variants ...'

      # first verify that I can really fix all of your line items

      no_live_variants_found = []
      variants_to_fix = []

      Spree::Variant.deleted.each do |variant|
        # check if this variant has any line items at all
        next if variant.line_items.none?

        variants_to_fix << variant
        dup_variant = Spree::Variant.find_by(sku: variant.sku)
        if dup_variant
          # this variant is OK
        else
          no_live_variants_found << variant
        end
      end

      if variants_to_fix.none?
        abort('ABORT: You have no deleted variants that are associated to line items. You do not need to run this raks task.')
      end

      if no_live_variants_found.any?
        puts "ABORT: Unfortunately, I found some deleted variants in your database that do not have matching non-deleted variants to replace them with. This script can only be used to cleanup deleted variants that have SKUs that match non-deleted variants. To continue, you must either (1) un-delete these variants (hint: mark them 'discontinued' instead) or (2) create new variants with a matching SKU for each variant in the list below."
        no_live_variants_found.each do |deleted_variant|
          puts "variant id #{deleted_variant.id} (sku is '#{deleted_variant.sku}') ... no match found"
        end
        abort
      end

      puts 'Ready to fix...'
      variants_to_fix.each do |variant|
        dup_variant = Spree::Variant.find_by(sku: variant.sku)
        puts "Changing all line items for #{variant.sku} variant id #{variant.id} (deleted) to variant id #{dup_variant.id} (not deleted) ..."
        Spree::LineItem.unscoped.where(variant_id: variant.id).update_all(variant_id: dup_variant.id)
      end

      puts 'DONE !   Your database should no longer have line items that are associated with deleted variants.'
    end
  end

  desc 'Migrates taxon icons to spree assets after upgrading to Spree 3.4: only needed if you used taxons icons.'
  task migrate_taxon_icons: :environment do |_t, _args|
    Spree::Taxon.where.not(icon_file_name: nil).find_each do |taxon|
      taxon.create_icon(attachment_file_name: taxon.icon_file_name,
                        attachment_content_type: taxon.icon_content_type,
                        attachment_file_size: taxon.icon_file_size,
                        attachment_updated_at: taxon.icon_updated_at)
    end
  end

  desc 'Migrates taxon icons to taxon images after upgrading to Spree 3.7: only needed if you used taxons icons.'
  task migrate_taxon_icons_to_images: :environment do |_t, _args|
    Spree::Asset.where(type: 'Spree::TaxonIcon').update_all(type: 'Spree::TaxonImage')
  end

  desc 'Ensure all Order associated with Store after upgrading to Spree 3.7'
  task associate_orders_with_store: :environment do |_t, _args|
    Spree::Order.where(store_id: nil).update_all(store_id: Spree::Store.default.id)
  end

  desc 'Ensure all Order has currency present after upgrading to Spree 3.7'
  task ensure_order_currency_presence: :environment do |_t, _args|
    Spree::Order.where(currency: nil).find_in_batches do |orders|
      orders.each do |order|
        order.update!(currency: order.store.default_currency)
      end
    end
  end

  task migrate_admin_users_to_role_users: :environment do |_t, _args|
    default_store = Spree::Store.default
    Spree::RoleUser.where(resource: nil).each do |role_user|
      role_user.update_columns(resource_type: default_store.class.name, resource_id: default_store.id)
    end
  end

  desc 'Migrate policies to store policies'
  task migrate_policies: :environment do |_t, _args|
    # Helper to consistently derive policy name
    derive_policy_name = lambda do |name_str|
      name_str.to_s.gsub(/customer_/, '').gsub(/_policy$/, '')
    end

    # Check if migration has already been run
    if Spree::Policy.any?
      puts "Policies already exist. Skipping migration to prevent duplicates."
      exit
    end

    Spree::Store.all.each do |store|
      %w[customer_terms_of_service customer_privacy_policy customer_returns_policy customer_shipping_policy].each do |policy_slug|
        policy = store.send(policy_slug)
        next unless policy.present?

        store.policies.create(
          name: Spree.t(derive_policy_name.call(policy_slug)),
          body: policy.body
        )

        puts "Migrated #{policy_slug} to store #{store.id}"
      end
    end

    Spree::PageLink.where(linkable_type: 'ActionText::RichText').each do |page_link|
      # Check if this page link is attached to ActionText content
      # Find the ActionText record
      action_text = ActionText::RichText.find_by(id: page_link.linkable_id)
      next unless action_text

      # Check if the ActionText belongs to a store policy
      if action_text.record_type == 'Spree::Store' && action_text.name.to_s.include?('policy')
        # Find the corresponding policy in the new policies system
        store = action_text.record
        policy_name = derive_policy_name.call(action_text.name)

        policy = store.policies.find_by(name: Spree.t(policy_name))

        if policy
          # Update the page link to point to the policy instead
          page_link.update!(
            linked_resource_type: 'Spree::Policy',
            linked_resource_id: policy.id
          )

          puts "Migrated #{policy_name} to store #{store.id}"
        end
      end
    end
  end

  desc 'Migrate product properties to metafields'
  task migrate_product_properties_to_metafields: :environment do |_t, _args|
    Spree::Property.find_each do |property|
      metafield_definition = Spree::MetafieldDefinition.find_or_initialize_by(
        namespace: 'properties',
        key: property.name,
        resource_type: 'Spree::Product'
      )
      metafield_definition.assign_attributes(
        metafield_type: property.kind_to_metafield_type,
        display_on: property.display_on
      )
      metafield_definition.save!

      property.product_properties.includes(:product).find_each do |product_property|
        product_property.product.set_metafield("properties.#{property.name}", product_property.value)
        puts "Migrated #{property.name} to product #{product_property.product.id}"
      end
    end
  end

  desc 'Migrate product details sections to PDP 2.0 with blocks and metafields'
  task migrate_product_details_pages: :environment do |_t, _args|
    Spree::PageSections::ProductDetails.find_each do |section|
      next if section.blocks.any?

      if defined?(SpreeMultiTenant)
        SpreeMultiTenant.with_tenant(section.tenant) do
          section.send(:create_blocks)
        end
      else
        section.send(:create_blocks)
      end
    end

    Spree::Pages::ProductDetails.find_each do |page|
      next if page.sections.exists?(type: 'Spree::PageSections::Breadcrumbs')

      block = proc do
        breadcrumbs = page.sections.create!(type: 'Spree::PageSections::Breadcrumbs')
        breadcrumbs.move_to_top

        page_details = page.sections.find_by(type: 'Spree::PageSections::ProductDetails')
        if page_details.present?
          page_details.update!(preferred_top_padding: 0, preferred_top_border_width: 0)
        end
      end

      if defined?(SpreeMultiTenant)
        SpreeMultiTenant.with_tenant(page.tenant, &block)
      else
        block.call
      end
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
