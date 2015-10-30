module SpreeCmd

  class Extension < Thor::Group
    include Thor::Actions

    desc "builds a spree extension"
    argument :file_name, :type => :string, :desc => 'rails app_path', :default => '.'
    class_option :preferences, alias: "-p", type: :boolean, default: false, desc: "generate namespaced configuration preferences"
    class_option :preference_pane, alias: "-pp", type: :boolean, default: false, desc: "generate backend configuration preference pane"

    source_root File.expand_path('../templates/extension', __FILE__)

    def generate
      use_prefix 'spree_'

      empty_directory file_name

      directory 'app', "#{file_name}/app"
      directory 'lib', "#{file_name}/lib"
      directory 'bin', "#{file_name}/bin"

      template 'extension.gemspec', "#{file_name}/#{file_name}.gemspec"
      template 'Gemfile', "#{file_name}/Gemfile"
      template 'gitignore', "#{file_name}/.gitignore"
      template 'LICENSE', "#{file_name}/LICENSE"
      template 'Rakefile', "#{file_name}/Rakefile"
      template 'README.md', "#{file_name}/README.md"
      template 'config/routes.rb', "#{file_name}/config/routes.rb"
      template 'config/locales/en.yml', "#{file_name}/config/locales/en.yml"
      template 'rspec', "#{file_name}/.rspec"
      template 'spec/spec_helper.rb.tt', "#{file_name}/spec/spec_helper.rb"

      if options[:preferences] || options[:preference_pane]
        directory '../extension_preferences/app', "#{file_name}/app"
      end

      if options[:preference_pane]
        directory '../extension_preference_pane/app', "#{file_name}/app"
        append_to_file "#{file_name}/config/locales/en.yml", i18n_strings
        insert_into_file "#{file_name}/config/routes.rb", routes, after: '  # Add your extension routes here'
      end
    end

    def final_banner
      say %Q{
        #{'*' * 80}

        Your extension has been generated with a gemspec dependency on Spree #{spree_version}.

        For more information on the versioning of Spree.
        See https://guides.spreecommerce.com/developer/extensions_tutorial.html#versioning-your-extension

        Consider listing your extension in the official extension registry https://spreecommerce.com/extensions

        #{'*' * 80}
      }
    end

    no_tasks do
      def class_name
        Thor::Util.camel_case file_name
      end

      def unprefixed_class_name
        Thor::Util.camel_case unprefixed_file_name
      end

      def unprefixed_file_name
        @file_name.match(/^#{@prefix}(.*)/)[1]
      end

      def spree_version
        '3.1.0.beta'
      end

      def use_prefix(prefix)
        @prefix = prefix
        unless file_name =~ /^#{prefix}/
          @file_name = prefix + Thor::Util.snake_case(file_name)
        end
      end

      def i18n_strings
        <<-END
  spree:
    #{ unprefixed_file_name }:
      menu_tab: #{ unprefixed_class_name }
      resource: #{ unprefixed_class_name } Extension
      preferences_title: #{ unprefixed_class_name } Preferences
      active: Active
        END
      end

      def routes
        <<-END

  namespace :admin do
    resource :#{ unprefixed_file_name }_preferences, only: [:edit, :update]
  end
        END
      end
    end

  end
end
