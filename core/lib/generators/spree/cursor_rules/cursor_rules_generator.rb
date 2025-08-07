module Spree
  class CursorRulesGenerator < Rails::Generators::Base
    desc 'Set up Cursor Rules - copies all Spree cursor rules to .cursor/rules directory'

    def self.source_paths
      paths = superclass.source_paths
      paths << File.expand_path('templates', __dir__)
      paths.flatten
    end

    def create_cursor_rules_directory
      empty_directory '.cursor/rules'
    end

    def copy_cursor_rules
      copy_file 'spree_rules.md', '.cursor/rules/spree_rules.md'
    end
  end
end
