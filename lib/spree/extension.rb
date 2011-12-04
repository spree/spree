module Spree
  class Extension < Thor
    include Thor::Actions

    def self.source_root
      File.dirname(__FILE__) + '/templates/extension'
    end

    desc "generate NAME", "generate extension"
    def generate(name)

      class_path = name.include?('/') ? name.split('/') : name.split('::')
      class_path.map! { |m| m.underscore }
      self.file_name = 'spree_' + class_path.pop.gsub('spree_', '')
      self.human_name = name.titleize
      self.class_name = file_name.classify

      empty_directory file_name

      directory "app", "#{file_name}/app"

      empty_directory "#{file_name}/app/controllers"
      empty_directory "#{file_name}/app/helpers"
      empty_directory "#{file_name}/app/models"
      empty_directory "#{file_name}/app/views"
      empty_directory "#{file_name}/app/overrides"
      empty_directory "#{file_name}/config"
      empty_directory "#{file_name}/config/locales"
      empty_directory "#{file_name}/db"

      directory "lib", "#{file_name}/lib"
      directory "script", "#{file_name}/script"

      empty_directory "#{file_name}/spec"

      template "LICENSE", "#{file_name}/LICENSE"
      template "Rakefile", "#{file_name}/Rakefile"
      template "README.md", "#{file_name}/README.md"
      template "gitignore", "#{file_name}/.gitignore"
      template "extension.gemspec", "#{file_name}/#{file_name}.gemspec"
      template "Versionfile", "#{file_name}/Versionfile"
      template "routes.rb", "#{file_name}/config/routes.rb"
      template "en.yml", "#{file_name}/config/locales/en.yml"
      template "Gemfile", "#{file_name}/Gemfile" unless integrated
      template "spec_helper.rb.tt", "#{file_name}/spec/spec_helper.rb"
      template "rspec", "#{file_name}/.rspec"

      if integrated
        append_to_file(gemfile) do
          "\ngem '#{file_name}', :path => '#{file_name}'"
        end
      end
    end

    no_tasks do
      # File/Lib Name (ex. spree_paypal_express)
      attr_accessor :file_name
    end

    no_tasks do
      # Human Readable Name (ex. Paypal Express)
      attr_accessor :human_name
    end

    no_tasks do
      # Class Name (ex. PaypalExpress)
      attr_accessor :class_name
    end

    protected
    def gemfile
      File.expand_path("Gemfile", Dir.pwd)
    end
    # extension is integrated with an existing rails app (as opposed to standalone repository)
    def integrated
      File.exist?(gemfile)
    end
  end
end
