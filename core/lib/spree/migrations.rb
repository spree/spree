module Spree
  class Migrations
    attr_reader :config, :engine_name

    # Takes the engine config block and engine name
    def initialize(config, engine_name)
      @config = config
      @engine_name = engine_name
    end

    # Puts warning when any engine migration is not present on the Rails app
    # db/migrate dir
    #
    # First split:
    #
    #   ["20131128203548", "update_name_fields_on_spree_credit_cards.spree.rb"]
    #
    # Second split should give the engine_name of the migration
    #
    #   ["update_name_fields_on_spree_credit_cards", "spree.rb"]
    #
    # Shouldn't run on test mode because migrations inside engine don't have
    # engine name on the file name
    def check
      if File.directory?(app_dir)
        engine_in_app = app_migrations.map do |file_name|
          name, engine = file_name.split('.', 2)
          next unless match_engine?(engine)
          name
        end.compact

        missing_migrations = engine_migrations.sort - engine_in_app.sort
        unless missing_migrations.empty?
          puts "[#{engine_name.capitalize} WARNING] Missing migrations."
          missing_migrations.each do |migration|
            puts "[#{engine_name.capitalize} WARNING] #{migration} from #{engine_name} is missing."
          end
          puts "[#{engine_name.capitalize} WARNING] Run `bundle exec rake railties:install:migrations` to get them.\n\n"
          true
        end
      end
    end

    private

    def engine_migrations
      Dir.entries(engine_dir).map do |file_name|
        name = file_name.split('_', 2).last.split('.', 2).first
        name.empty? ? next : name
      end.compact! || []
    end

    def app_migrations
      Dir.entries(app_dir).map do |file_name|
        next if ['.', '..'].include? file_name
        name = file_name.split('_', 2).last
        name.empty? ? next : name
      end.compact! || []
    end

    def app_dir
      "#{Rails.root}/db/migrate"
    end

    def engine_dir
      "#{config.root}/db/migrate"
    end

    def match_engine?(engine)
      if engine_name == 'spree'
        # Avoid stores upgrading from 1.3 getting wrong warnings
        ['spree.rb', 'spree_promo.rb'].include? engine
      else
        engine == "#{engine_name}.rb"
      end
    end
  end
end
