#!/usr/bin/env ruby

# Builds pre-configured test applications for CI reuse
# Usage: bin/build-test-apps.rb [postgres|mysql]
#
# Creates two template types:
# - basic: for core, api (uses root Gemfile, LegacyUser, minimal config)
# - full: for admin, storefront, page_builder, emails, sample (Devise, full assets)

require 'pathname'
require 'fileutils'

class TestAppBuilder
  ROOT = Pathname.pwd.freeze
  OUTPUT_DIR = Pathname.new('/tmp/prebuilt-test-apps').freeze

  TEMPLATE_CONFIGS = {
    'basic' => {
      lib_name: 'spree/core',
      authentication: 'dummy',
      user_class: 'Spree::LegacyUser',
      admin_user_class: nil,
      install_admin: false,
      install_storefront: false,
      javascript: false,
      css: false
    },
    'full' => {
      lib_name: 'spree/admin',
      authentication: 'devise',
      user_class: 'Spree::User',
      admin_user_class: 'Spree::AdminUser',
      install_admin: true,
      install_storefront: true,
      javascript: true,
      css: true
    }
  }.freeze

  def initialize(db_type)
    @db_type = validate_db_type(db_type)
  end

  def build_all
    prepare_output_directory
    TEMPLATE_CONFIGS.each_key do |template_type|
      build_template(template_type)
    end
    log "All templates built successfully in #{OUTPUT_DIR}"
  end

  private

  def validate_db_type(db_type)
    valid_types = %w[postgres mysql]
    unless valid_types.include?(db_type)
      raise ArgumentError, "Invalid database type: #{db_type}. Must be one of: #{valid_types.join(', ')}"
    end
    db_type
  end

  def prepare_output_directory
    FileUtils.rm_rf(OUTPUT_DIR)
    FileUtils.mkdir_p(OUTPUT_DIR)
  end

  def build_template(template_type)
    log "Building #{template_type} template for #{@db_type}..."
    config = TEMPLATE_CONFIGS[template_type]
    template_dir = OUTPUT_DIR.join(template_type)

    # Build the test app in a temporary location within the appropriate gem directory
    # We need to be in the gem directory for Bundler to work correctly
    gem_dir = template_type == 'basic' ? ROOT.join('core') : ROOT.join('admin')

    Dir.chdir(gem_dir) do
      ENV['DB'] = @db_type
      ENV['LIB_NAME'] = config[:lib_name]
      ENV['DUMMY_PATH'] = template_dir.to_s

      # Generate the Rails app and run all setup
      build_command = build_rake_command(config)
      log "Running: #{build_command}"
      system(build_command) || raise("Failed to build #{template_type} template")
    end

    # Store metadata about the template
    write_template_metadata(template_dir, template_type, config)

    log "#{template_type} template built successfully at #{template_dir}"
  end

  def build_rake_command(config)
    # Use the root Gemfile for core gems, local for others
    gemfile = config[:lib_name].start_with?('spree/core', 'spree/api') ? ROOT.join('Gemfile') : './Gemfile'

    args = []
    args << "authentication:#{config[:authentication]}"
    args << "user_class:#{config[:user_class]}"
    args << "admin_user_class:#{config[:admin_user_class]}" if config[:admin_user_class]
    args << "install_admin:#{config[:install_admin]}"
    args << "install_storefront:#{config[:install_storefront]}"
    args << "javascript:#{config[:javascript]}"
    args << "css:#{config[:css]}"

    "bundle exec --gemfile=#{gemfile} rake common:test_app[#{args.join(',')}]"
  end

  def write_template_metadata(template_dir, template_type, config)
    metadata = {
      'template_type' => template_type,
      'db_type' => @db_type,
      'config' => config,
      'built_at' => Time.now.iso8601
    }

    File.write(template_dir.join('.prebuilt_metadata.yml'), metadata.to_yaml)
  end

  def log(message)
    puts "[build-test-apps] #{message}"
  end
end

if __FILE__ == $0
  db_type = ARGV[0] || 'postgres'

  begin
    builder = TestAppBuilder.new(db_type)
    builder.build_all
  rescue => e
    puts "Error: #{e.message}"
    puts e.backtrace.first(5).join("\n") if ENV['DEBUG']
    exit 1
  end
end
