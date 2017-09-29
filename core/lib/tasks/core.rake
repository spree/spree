require 'active_record'

namespace :db do
  desc %q{Loads a specified fixture file:
use rake db:load_file[/absolute/path/to/sample/filename.rb]}

  task :load_file, [:file, :dir] => :environment do |_t, args|
    file = Pathname.new(args.file)

    puts "loading ruby #{file}"
    require file
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
      # If file exists within application it takes precendence.
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

    # remigrate unless production mode (as saftey check)
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
    unless load_defaults # ask if there are already Countries => default data hass been loaded
      load_defaults = agree('Countries present, load sample data anyways? [y/n]: ')
    end
    Rake::Task['db:seed'].invoke if load_defaults

    if Rails.env.production? && Spree::Product.count > 0
      load_sample = agree('WARNING: In Production and products exist in database, load sample data anyways? [y/n]:')
    else
      load_sample = true if ENV['AUTO_ACCEPT']
      load_sample = agree('Load Sample Data? [y/n]: ') unless load_sample
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

    puts 'WARNING: This task will re-associate any line_items associated with deleted variants to non-deleted variants with matching SKUs. Because other attributes and product associations may switch during the re-association, this may have unintended side-effects. If this task finishes successfully, line items for old order should no longer be orphaned from their varaints. You should run this task after you have already run the db migratoin AddDiscontinuedToProductsAndVariants. If the db migration did not warn you that it was leaving deleted records in place because of duplicate SKUs, then you do not need to run this rake task.'
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
end
