module SpreeAssistant
  module Generators
    # Copies the assistant's migrations into the host app.
    #
    # Also what `rake test_app` invokes, so the dummy app used by the specs
    # gets the three tables — without this the whole suite fails on a fresh
    # checkout with "Could not find table 'spree_assistant_chats'".
    class InstallGenerator < Rails::Generators::Base
      class_option :auto_run_migrations, type: :boolean, default: false

      def add_migrations
        run 'bundle exec rake railties:install:migrations FROM=spree_assistant'
      end

      def run_migrations
        return unless options[:auto_run_migrations] ||
                      ask('Would you like to run the migrations now? [Y/n]').casecmp('y').zero?

        run 'bundle exec rake db:migrate'
      end
    end
  end
end
