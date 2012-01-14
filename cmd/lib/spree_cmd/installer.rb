module SpreeCmd

  class Installer < Thor::Group
    include Thor::Actions

    desc "Creates a new rails project with a spree store"
    argument :app_path, :type => :string, :desc => 'rails app_path', :default => '.'

    class_option :auto_accept, :type => :boolean, :aliases => '-A', :desc => "Answer yes to all prompts"

    class_option :skip_install_data, :type => :boolean, :default => false,
                 :desc => 'Skip running migrations and loading seed and sample data'

    class_option :version, :type => :string, :default => 'current',
                 :desc => 'Spree Version to use (current, edge, local)'

    class_option :edge, :type => :boolean

    class_option :path, :type => :string, :desc => 'Spree gem path'
    class_option :git, :type => :string, :desc => 'Spree gem git url'
    class_option :ref, :type => :string, :desc => 'Spree gem git ref'
    class_option :branch, :type => :string, :desc => 'Spree gem git branch'
    class_option :tag, :type => :string, :desc => 'Spree gem git tag'

    def verify_rails
      unless is_rails_project?
        say "#{@app_path} rails project not found"
        exit(1)
      end
    end

    def prepare_options
      @spree_gem_options = {}

      if options[:edge]
        @spree_gem_options[:git] = 'https://github.com/spree/spree.git'
      elsif options[:path]
        @spree_gem_options[:path] = options[:path]
      elsif options[:git]
        @spree_gem_options[:git] = options[:git]
        @spree_gem_options[:ref] = options[:ref] if options[:ref]
        @spree_gem_options[:branch] = options[:branch] if options[:branch]
        @spree_gem_options[:tag] = options[:tag] if options[:tag]
      end
    end

    def ask_questions
      @install_blue_theme = ask_with_default("Would you like to install the default blue theme?")
      @install_default_gateways = ask_with_default("Would you like to install the default gateways?")

      if options[:skip_install_data]
        @run_migrations = false
        @load_seed_data = false
        @load_sample_data = false
      else
        @run_migrations = ask_with_default("Would you like to run the migrations?")
        if @run_migrations
          @load_seed_data = ask_with_default("Would you like to load the seed data?")
          @load_sample_data = ask_with_default("Would you like to load the sample data?")
        else
          @load_seed_data = false
          @load_sample_data = false
        end
      end
    end

    def add_gems
      inside @app_path  do

        gem :spree, @spree_gem_options

        if @install_blue_theme
          gem :spree_blue_theme, { :git => 'git://github.com/spree/spree_blue_theme.git',
                                   :ref => '10666404ccb3ed4a4cc9cbe41e822ab2bb55112e' }
        end

        if @install_default_gateways
          gem :spree_usa_epay, { :git => 'git://github.com/spree/spree_usa_epay.git',
                                 :ref => '0cb57b4afbf1eef6a0ad67a4a1ea506c6418fde1' }

          gem :spree_skrill, { :git => 'git://github.com/spree/spree_skrill.git',
                               :ref => '6743bcbd0146d1c7145d6befc648005d8d0cf79a' }
        end

        run 'bundle install'
      end
    end

    def initialize_spree
      spree_options = []
      spree_options << "--migrate=#{@run_migrations}"
      spree_options << "--seed=#{@load_seed_data}"
      spree_options << "--sample=#{@load_sample_data}"
      spree_options << "--auto_accept" if options[:auto_accept]

      inside @app_path do
        run "rails generate spree:install #{spree_options.join(' ')}"
      end
    end

    private

    def gem(name, options={})
      say_status :gemfile, name
      parts = ["'#{name}'"]
      options.each {|key, value| parts << ":#{key} => '#{value}'" }
      append_file "Gemfile", "gem #{parts.join(', ')}\n", :verbose => false
    end

    def ask_with_default(message, default='yes')
      return true if options[:auto_accept]

      valid = false
      until valid
        response = ask "#{message} (yes/no) [#{default}]"
        response = default if response.empty?
        valid = (response  =~ /\Ay(?:es)?|no?\Z/i)
      end
      response.downcase[0] == ?y
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
