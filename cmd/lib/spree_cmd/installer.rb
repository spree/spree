module SpreeCmd

  class Installer < Thor::Group
    include Thor::Actions

    desc 'Creates a new rails project with a spree store'
    argument :app_path, :type => :string, :desc => 'rails app_path', :default => '.'

    class_option :auto_accept, :type => :boolean, :aliases => '-A',
                               :desc => 'Answer yes to all prompts'

    class_option :skip_install_data, :type => :boolean, :default => false,
                 :desc => 'Skip running migrations and loading seed and sample data'

    class_option :version, :type => :string, :desc => 'Spree Version to use'

    class_option :edge, :type => :boolean

    class_option :path, :type => :string, :desc => 'Spree gem path'
    class_option :git, :type => :string, :desc => 'Spree gem git url'
    class_option :ref, :type => :string, :desc => 'Spree gem git ref'
    class_option :branch, :type => :string, :desc => 'Spree gem git branch'
    class_option :tag, :type => :string, :desc => 'Spree gem git tag'

    class_option :precompile_assets, :type => :boolean, :default => true,
                 :desc => 'Precompile spree assets to public/assets'

    def verify_rails
      unless is_rails_project?
        say "#{@app_path} is not a rails project."
        exit(1)
      end
    end

    def prepare_options
      @spree_gem_options = {}

      if options[:edge]
        @spree_gem_options[:git] = 'git://github.com/spree/spree.git'
      elsif options[:path]
        @spree_gem_options[:path] = options[:path]
      elsif options[:git]
        @spree_gem_options[:git] = options[:git]
        @spree_gem_options[:ref] = options[:ref] if options[:ref]
        @spree_gem_options[:branch] = options[:branch] if options[:branch]
        @spree_gem_options[:tag] = options[:tag] if options[:tag]
      elsif options[:version]
        @spree_gem_options[:version] = options[:version]
      end
    end

    def ask_questions
      @install_default_gateways = ask_with_default('Would you like to install the default gateways?')

      if options[:skip_install_data]
        @run_migrations = false
        @load_seed_data = false
        @load_sample_data = false
      else
        @run_migrations = ask_with_default('Would you like to run the migrations?')
        if @run_migrations
          @load_seed_data = ask_with_default('Would you like to load the seed data?')
          @load_sample_data = ask_with_default('Would you like to load the sample data?')
        else
          @load_seed_data = false
          @load_sample_data = false
        end
      end

      if @load_seed_data
        @admin_email = ask_string('Admin Email', 'spree@example.com', /^([\w\.%\+\-]+)@([\w\-]+\.)+([\w]{2,})$/i)
        @admin_password = ask_string('Admin Password', 'spree123', /^\S{5,32}$/)
      end
      @precompile_assets = options[:precompile_assets] ? ask_with_default('Would you like to precompile assets?') : false
    end

    def add_gems
      inside @app_path  do

        gem :spree, @spree_gem_options

        if @install_default_gateways
          gem :spree_usa_epay
          gem :spree_skrill
        end

        run 'bundle install', :capture => true
      end
    end

    def initialize_spree
      spree_options = []
      spree_options << "--migrate=#{@run_migrations}"
      spree_options << "--seed=#{@load_seed_data}"
      spree_options << "--sample=#{@load_sample_data}"
      spree_options << "--auto_accept" if options[:auto_accept]
      spree_options << "--admin_email=#{@admin_email}" if @admin_email
      spree_options << "--admin_password=#{@admin_password}" if @admin_password

      inside @app_path do
        run "rails generate spree:install #{spree_options.join(' ')}", :verbose => false
      end
    end

    def precompile_assets
      if @precompile_assets
        say_status :precompiling, 'assets'
        inside @app_path do
          run 'bundle exec rake assets:precompile', :verbose => false
        end
      end
    end

    private

      def gem(name, gem_options={})
        say_status :gemfile, name
        parts = ["'#{name}'"]
        parts << ["'#{gem_options.delete(:version)}'"] if gem_options[:version]
        gem_options.each { |key, value| parts << ":#{key} => '#{value}'" }
        append_file 'Gemfile', "gem #{parts.join(', ')}\n", :verbose => false
      end

      def ask_with_default(message, default = 'yes')
        return true if options[:auto_accept]

        valid = false
        until valid
          response = ask "#{message} (yes/no) [#{default}]"
          response = default if response.empty?
          valid = (response  =~ /\Ay(?:es)?|no?\Z/i)
        end
        response.downcase[0] == ?y
      end

      def ask_string(message, default, valid_regex = /\w/)
        return default if options[:auto_accept]
        valid = false
        until valid
          response = ask "#{message} [#{default}]"
          response = default if response.empty?
          valid = (response  =~ valid_regex)
        end
        response
      end

      def create_rails_app
        say :create, @app_path

        rails_cmd = "rails new #{@app_path} --skip-bundle"
        if options[:template]
          rails_cmd += " -m #{options[:template]}"
        end
        if options[:database]
          rails_cmd += " -d #{options[:database]}"
        end
        run(rails_cmd)
      end

      def is_rails_project?
        File.exists? File.join(@app_path, 'script', 'rails')
      end
  end
end
