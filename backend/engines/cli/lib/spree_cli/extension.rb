require 'active_support/core_ext/string/inflections'

module SpreeCli
  class Extension < Thor::Group
    include Thor::Actions

    desc 'builds a spree extension'
    argument :file_name, type: :string, desc: 'rails app_path', default: 'sample_extension'

    source_root File.expand_path('templates/extension', __dir__)

    def generate
      use_prefix 'spree_'

      empty_directory file_name

      directory 'app',      "#{file_name}/app"
      directory 'lib',      "#{file_name}/lib"
      directory 'bin',      "#{file_name}/bin"
      directory 'spec',     "#{file_name}/spec"

      empty_directory "#{file_name}/app/models/#{file_name}"
      empty_directory "#{file_name}/app/views/spree"
      empty_directory "#{file_name}/app/controllers/spree/admin"
      empty_directory "#{file_name}/app/controllers/#{file_name}"
      empty_directory "#{file_name}/app/services/#{file_name}"
      empty_directory "#{file_name}/app/serializers/spree/api/v3"
      empty_directory "#{file_name}/app/serializers/spree/api/v3/admin"
      empty_directory "#{file_name}/vendor/javascript"
      empty_directory "#{file_name}/vendor/stylesheets"

      chmod "#{file_name}/bin/rails", 0o755
      chmod "#{file_name}/bin/importmap", 0o755

      template 'extension.gemspec', "#{file_name}/#{file_name}.gemspec"
      template 'Gemfile', "#{file_name}/Gemfile"
      template 'gitignore', "#{file_name}/.gitignore"
      template 'LICENSE.md', "#{file_name}/LICENSE.md"
      template 'Rakefile', "#{file_name}/Rakefile"
      template 'README.md', "#{file_name}/README.md"
      template 'config/routes.rb', "#{file_name}/config/routes.rb"
      template 'config/locales/en.yml', "#{file_name}/config/locales/en.yml"
      template 'config/initializers/spree.rb', "#{file_name}/config/initializers/spree.rb"
      template 'config/importmap.rb', "#{file_name}/config/importmap.rb"

      template 'rspec', "#{file_name}/.rspec"
      template '.github/workflows/tests.yml', "#{file_name}/.github/workflows/tests.yml"
      template '.github/.dependabot.yml', "#{file_name}/.github/.dependabot.yml"
      template '.rubocop.yml', "#{file_name}/.rubocop.yml"
      template '.gem_release.yml', "#{file_name}/.gem_release.yml"
    end

    def final_banner
      say %{
        #{'*' * 80}

        Congrats, Your Spree #{human_name} extension has been generated 🚀

        Next steps:
        * Read Spree Developer Documentation at: https://docs.spreecommerce.org/developer

        #{'*' * 80}
      }
    end

    no_tasks do
      def class_name
        Thor::Util.camel_case file_name
      end

      def human_name
        file_name.to_s.gsub('spree_', '').humanize
      end

      def use_prefix(prefix)
        @file_name = prefix + Thor::Util.snake_case(file_name) unless file_name =~ /^#{prefix}/
      end
    end
  end
end
