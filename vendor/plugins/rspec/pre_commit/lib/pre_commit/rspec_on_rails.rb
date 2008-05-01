class PreCommit::RspecOnRails < PreCommit
  def pre_commit
    install_plugins
    check_dependencies
    used_railses = []
    VENDOR_DEPS.each do |dependency|
      rails_dir = File.expand_path(dependency[:checkout_path])
      rails_version = rails_version_from_dir(rails_dir)
      begin
        rspec_pre_commit(rails_version, false)
        used_railses << rails_version
      rescue Exception => e
        unless rails_version == 'edge'
          raise e
        end
      end
    end
    uninstall_plugins
    puts "All specs passed against the following released versions of Rails: #{used_railses.join(", ")}"
    unless used_railses.include?('edge')
      puts "There were errors running pre_commit against edge"
    end
  end

  def rails_version_from_dir(rails_dir)
    File.basename(rails_dir)
  end

  def rspec_pre_commit(rails_version=ENV['RSPEC_RAILS_VERSION'],uninstall=true)
    puts "#####################################################"
    puts "running pre_commit against rails #{rails_version}"
    puts "#####################################################"
    ENV['RSPEC_RAILS_VERSION'] = rails_version
    cleanup(uninstall)
    ensure_db_config
    clobber_sqlite_data
    install_plugins
    generate_rspec

    generate_login_controller
    create_purchase

    rake_sh "spec"
    rake_sh "spec:plugins:rspec_on_rails"
    
    # TODO - why is this necessary? Shouldn't the specs leave
    # a clean DB?
    rake_sh "db:test:prepare"
    sh "ruby vendor/plugins/rspec_on_rails/stories/all.rb"
    cleanup(uninstall)
  end

  def cleanup(uninstall=true)
    revert_routes
    rm_generated_login_controller_files
    destroy_purchase
    uninstall_plugins if uninstall
  end

  def revert_routes
    output = silent_sh("cp config/routes.rb.bak config/routes.rb")
    raise "Error reverting routes.rb" if shell_error?(output)
  end

  def create_purchase
    generate_purchase
    migrate_up
  end

  def install_plugins
    install_rspec_on_rails_plugin
    install_rspec_plugin
  end

  def install_rspec_on_rails_plugin
    rm_rf 'vendor/plugins/rspec_on_rails'
    copy '../rspec_on_rails', 'vendor/plugins/'
  end

  def install_rspec_plugin
    rm_rf 'vendor/plugins/rspec'
    copy '../rspec', 'vendor/plugins/'
  end

  def uninstall_plugins
    rm_rf 'vendor/plugins/rspec_on_rails'
    rm_rf 'vendor/plugins/rspec'
    rm_rf 'script/spec'
    rm_rf 'script/spec_server'
    rm_rf 'spec/spec_helper.rb'
    rm_rf 'spec/spec.opts'
    rm_rf 'spec/rcov.opts'
  end
  
  def copy(source, target)
    output = silent_sh("cp -R #{File.expand_path(source)} #{File.expand_path(target)}")
    raise "Error installing rspec" if shell_error?(output)
  end
  
  def generate_rspec
    result = silent_sh("ruby script/generate rspec --force")
    if error_code? || result =~ /^Missing/
      raise "Failed to generate rspec environment:\n#{result}"
    end
  end

  def ensure_db_config
    config_path = 'config/database.yml'
    unless File.exists?(config_path)
      message = <<-EOF
      #####################################################
      Could not find #{config_path}

      You can get rake to generate this file for you using either of:
        rake rspec:generate_mysql_config
        rake rspec:generate_sqlite3_config

      If you use mysql, you'll need to create dev and test
      databases and users for each. To do this, standing
      in rspec_on_rails, log into mysql as root and then...
        mysql> source db/mysql_setup.sql;

      There is also a teardown script that will remove
      the databases and users:
        mysql> source db/mysql_teardown.sql;
      #####################################################
      EOF
      raise message.gsub(/^      /, '')
    end
  end

  def generate_mysql_config
    copy 'config/database.mysql.yml', 'config/database.yml'
  end

  def generate_sqlite3_config
    copy 'config/database.sqlite3.yml', 'config/database.yml'
  end

  def clobber_db_config
    rm 'config/database.yml'
  end

  def clobber_sqlite_data
    rm_rf 'db/*.db'
  end

  def generate_purchase
    generator = "ruby script/generate rspec_scaffold purchase order_id:integer created_at:datetime amount:decimal keyword:string description:text --force"
    notice = <<-EOF
    #####################################################
    #{generator}
    #####################################################
    EOF
    puts notice.gsub(/^    /, '')
    result = silent_sh(generator)
    if error_code? || result =~ /not/
      raise "rspec_scaffold failed. #{result}"
    end
  end
  
  def purchase_migration_version
    "005"
  end

  def migrate_up
    rake_sh "db:migrate"
  end

  def destroy_purchase
    migrate_down
    rm_generated_purchase_files
  end

  def migrate_down
    notice = <<-EOF
    #####################################################
    Migrating down and reverting config/routes.rb
    #####################################################
    EOF
    puts notice.gsub(/^    /, '')
    rake_sh "db:migrate", 'VERSION' => (purchase_migration_version.to_i - 1)
    output = silent_sh("cp config/routes.rb.bak config/routes.rb")
    raise "revert failed: #{output}" if error_code?
  end

  def rm_generated_purchase_files
    puts "#####################################################"
    puts "Removing generated files:"
    generated_files = %W{
      app/helpers/purchases_helper.rb
      app/models/purchase.rb
      app/controllers/purchases_controller.rb
      app/views/purchases
      db/migrate/#{purchase_migration_version}_create_purchases.rb
      spec/models/purchase_spec.rb
      spec/helpers/purchases_helper_spec.rb
      spec/controllers/purchases_controller_spec.rb
      spec/controllers/purchases_routing_spec.rb
      spec/fixtures/purchases.yml
      spec/views/purchases
    }
    generated_files.each do |file|
      rm_rf file
    end
    puts "#####################################################"
  end
  
  def generate_login_controller
    generator = "ruby script/generate rspec_controller login signup login logout --force"
    notice = <<-EOF
    #####################################################
    #{generator}
    #####################################################
    EOF
    puts notice.gsub(/^    /, '')
    result = silent_sh(generator)
    if error_code? || result =~ /not/
      raise "rspec_scaffold failed. #{result}"
    end
  end

  def rm_generated_login_controller_files
    puts "#####################################################"
    puts "Removing generated files:"
    generated_files = %W{
      app/helpers/login_helper.rb
      app/controllers/login_controller.rb
      app/views/login
      spec/helpers/login_helper_spec.rb
      spec/controllers/login_controller_spec.rb
      spec/views/login
    }
    generated_files.each do |file|
      rm_rf file
    end
    puts "#####################################################"
  end

  def install_dependencies
    VENDOR_DEPS.each do |dep|
      puts "\nChecking for #{dep[:name]} ..."
      dest = dep[:checkout_path]
      if File.exists?(dest)
        puts "#{dep[:name]} already installed"
      else
        cmd = "svn co #{dep[:url]} #{dest}"
        puts "Installing #{dep[:name]}"
        puts "This may take a while."
        puts cmd
        system(cmd)
        puts "Done!"
      end
    end
    puts
  end

  def check_dependencies
    VENDOR_DEPS.each do |dep|
      unless File.exist?(dep[:checkout_path])
        raise "There is no checkout of #{dep[:checkout_path]}. Please run rake install_dependencies"
      end
      # Verify that the current working copy is right
      if `svn info #{dep[:checkout_path]}` =~ /^URL: (.*)/
        actual_url = $1
        if actual_url != dep[:url]
          raise "Your working copy in #{dep[:checkout_path]} points to \n#{actual_url}\nIt has moved to\n#{dep[:url]}\nPlease delete the working copy and run rake install_dependencies"
        end
      end
    end
  end
  
  def update_dependencies
    check_dependencies
    VENDOR_DEPS.each do |dep|
      next if dep[:tagged?] #
      puts "\nUpdating #{dep[:name]} ..."
      dest = dep[:checkout_path]
      system("svn cleanup #{dest}")
      cmd = "svn up #{dest}"
      puts cmd
      system(cmd)
      puts "Done!"
    end
  end

  VENDOR_DEPS = [
    {
      :checkout_path => "vendor/rails/2.0.2",
      :name =>  "rails 2.0.2",
      :url => "http://dev.rubyonrails.org/svn/rails/tags/rel_2-0-2",
      :tagged? => true
    },
    {
      :checkout_path => "vendor/rails/1.2.6",
      :name =>  "rails 1.2.6",
      :url => "http://dev.rubyonrails.org/svn/rails/tags/rel_1-2-6",
      :tagged? => true
    },
    {
      :checkout_path => "vendor/rails/1.2.3",
      :name =>  "rails 1.2.3",
      :url => "http://dev.rubyonrails.org/svn/rails/tags/rel_1-2-3",
      :tagged? => true
    },
    {
      :checkout_path => "vendor/rails/edge",
      :name =>  "edge rails",
      :url => "http://svn.rubyonrails.org/rails/trunk",
      :tagged? => false
    }
  ]
end
