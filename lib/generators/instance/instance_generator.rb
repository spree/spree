#######################################################################################################
# Substantial portions of this code were adapted from the Radiant CMS project (http://radiantcms.org) #
#######################################################################################################

require 'rbconfig'
require 'digest/md5'
require 'rails_generator/secret_key_generator'

class InstanceGenerator < Rails::Generator::Base
  DEFAULT_SHEBANG = File.join(Config::CONFIG['bindir'],
                              Config::CONFIG['ruby_install_name'])
  
  DATABASES = %w( mysql postgresql sqlite3 sqlserver )
  
  MYSQL_SOCKET_LOCATIONS = [
    "/tmp/mysql.sock",                        # default
    "/var/run/mysqld/mysqld.sock",            # debian/gentoo
    "/var/tmp/mysql.sock",                    # freebsd
    "/var/lib/mysql/mysql.sock",              # fedora
    "/opt/local/lib/mysql/mysql.sock",        # fedora
    "/opt/local/var/run/mysqld/mysqld.sock",  # mac + darwinports + mysql
    "/opt/local/var/run/mysql4/mysqld.sock",  # mac + darwinports + mysql4
    "/opt/local/var/run/mysql5/mysqld.sock"   # mac + darwinports + mysql5
  ]
    
  default_options :db => "sqlite3", :shebang => DEFAULT_SHEBANG, :freeze => false

  def initialize(runtime_args, runtime_options = {})
    super
    usage if args.empty?
    usage("Databases supported for preconfiguration are: #{DATABASES.join(", ")}") if (options[:db] && !DATABASES.include?(options[:db]))
    @destination_root = args.shift
    @app_name = File.basename(File.expand_path(@destination_root))
  end

  def manifest
    
    md5 = Digest::MD5.new
    now = Time.now
    md5 << now.to_s
    md5 << String(now.usec)
    md5 << String(rand(0))
    md5 << String($$)
    md5 << @app_name
 
    # Do our best to generate a secure secret key for CookieStore
    secret = ActiveSupport::SecureRandom.hex(64)
        
    # The absolute location of the Spree files
    root = File.expand_path(SPREE_ROOT) 
    
    # Use /usr/bin/env if no special shebang was specified
    script_options     = { :chmod => 0755, :shebang => options[:shebang] == DEFAULT_SHEBANG ? nil : options[:shebang] }
    dispatcher_options = { :chmod => 0755, :shebang => options[:shebang] }
    
    record do |m|
      # Root directory
      m.directory ""
      
      # Standard files and directories
      base_dirs = %w(config config/environments config/initializers db log script public vendor/plugins vendor/extensions)
      text_files = %w(CHANGELOG CONTRIBUTORS LICENSE INSTALL README.markdown)
      environments = Dir["#{root}/config/environments/*.rb"]
      scripts = Dir["#{root}/script/**/*"].reject { |f| f =~ /(destroy|generate)$/ }
      public_files = ["public/.htaccess.example"] + Dir["#{root}/public/**/*"]
      frozen_gems =  Dir["#{root}/vendor/gems/**/*"]
      
      files = base_dirs + text_files + environments + scripts + public_files + frozen_gems
      files.map! { |f| f = $1 if f =~ %r{^#{root}/(.+)$}; f }
      
      # hack to add specification (we're ignoring other hidden files)
      files << "vendor/gems/active_presenter-0.0.6/.specification"
      files.sort!
      
      files.each do |file|
        case
        when File.directory?("#{root}/#{file}")
          m.directory file
        when file =~ %r{^script/}
          m.file spree_root(file), file, script_options
        when file =~ %r{^public/dispatch}
          m.file spree_root(file), file, dispatcher_options
        when file =~ %r{^public/robots\.txt}
          # we'll use a special robots.txt if creating a demo instance
          m.file spree_root(file), file unless options[:demo]
        else
          m.file spree_root(file), file
        end
      end
      
      # script/generate
      m.file "instance_generate", "script/generate", script_options
      
      # database.yml and .htaccess
      m.template "databases/#{options[:db]}.yml", "config/database.yml", :assigns => {
        :app_name => File.basename(File.expand_path(@destination_root)),
        :socket   => options[:db] == "mysql" ? mysql_socket_location : nil
      }

      # Instance Rakefile
      m.file "instance_rakefile", "Rakefile"

      # Instance Configurations
      m.file "instance_routes.rb", "config/routes.rb"
      m.template "../../../../config/environment.rb", "config/environment.rb", :assigns => { :app_name => @app_name, :app_secret_key_to_be_replaced_in_real_app_by_generator => secret }
      m.file "../../../../config/boot.rb", "config/boot.rb"
      m.file "../../../../config/initializers/spree.rb", "config/initializers/spree.rb"
      m.file "../../../../config/initializers/locales.rb", "config/initializers/locales.rb"
      m.file "../../../../config/spree_permissions.yml", "config/spree_permissions.yml"
      
      # Demo Configuration
      if options[:demo]
        m.file "demo_mongrel_cluster.yml", "config/mongrel_cluster.yml"
        m.file "demo_robots.txt", "public/robots.txt"
      end
      
      # Install Readme
      m.readme spree_root("INSTALL")
    end
  end

  protected

    def banner
      "Usage: #{$0} /path/to/spree/app [options]"
    end

    def add_options!(opt)
      opt.separator ''
      opt.separator 'Options:'
      opt.on("-r", "--ruby=path", String,
             "Path to the Ruby binary of your choice (otherwise scripts use env, dispatchers current path).",
             "Default: #{DEFAULT_SHEBANG}") { |v| options[:shebang] = v }
      opt.on("-d", "--database=name", String,
            "Preconfigure for selected database (options: #{DATABASES.join(", ")}).",
            "Default: mysql") { |v| options[:db] = v }
    end
    
    def mysql_socket_location
      RUBY_PLATFORM =~ /mswin32/ ? MYSQL_SOCKET_LOCATIONS.find { |f| File.exists?(f) } : nil
    end

  private

    def spree_root(filename = '')
      File.join("..", "..", "..", "..", filename)
    end
  
end
