# frozen_string_literal: true

module Spree
  module PageBuilder
    module Generators
      class InstallGenerator < Rails::Generators::Base
        class_option :migrate, type: :boolean, default: true

        def add_migrations
          run 'bundle exec rake railties:install:migrations FROM=spree_page_builder'
        end

        def run_migrations
          if options[:migrate]
            run 'bin/rails db:migrate'
          else
            puts 'Skipping rails db:migrate, don\'t forget to run it!'
          end
        end
      end
    end
  end
end
