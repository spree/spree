module SpreeCmd

  class Extension < Thor::Group
    include Thor::Actions

    desc "builds a spree extension"
    argument :file_name, :type => :string, :desc => 'rails app_path', :default => '.'
    class_option :preferences, alias: "-p", type: :boolean, default: false, desc: 'generate namespaced configuration preferences'

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

      if options[:preferences]
        directory '../extension_preferences/app', "#{file_name}/app"
      end
    end

    def final_banner
      say %Q{
        #{'*' * 80}

        Your extension has been generated with a gemspec dependency on Spree #{spree_version}.

        Please update the Versionfile to designate compatibility with different versions of Spree.
        See http://spreecommerce.com/documentation/extensions.html#versionfile

        Consider listing your extension in the official extension registry http://spreecommerce.com/extensions

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
    end

  end
end
