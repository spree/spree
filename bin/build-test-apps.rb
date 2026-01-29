#!/usr/bin/env ruby

# Builds pre-configured test applications for CI reuse
# Usage: bin/build-test-apps.rb [postgres|mysql]
#
# Creates two template types:
# - basic: for core, api, emails, sample (LegacyUser only, minimal config)
# - full: for admin, storefront, page_builder (LegacyUser + LegacyAdminUser, full assets)

require 'pathname'
require 'fileutils'
require 'yaml'

class TestAppBuilder
  ROOT = Pathname.pwd.freeze
  OUTPUT_DIR = Pathname.new('/tmp/prebuilt-test-apps').freeze

  TEMPLATE_CONFIGS = {
    'basic' => {
      gem_dir: 'core',
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
      gem_dir: 'admin',
      lib_name: 'spree/admin',
      authentication: 'dummy',
      user_class: 'Spree::LegacyUser',
      admin_user_class: 'Spree::LegacyAdminUser',
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

    # Build the test app from within the appropriate gem directory
    gem_dir = ROOT.join(config[:gem_dir])

    Dir.chdir(gem_dir) do
      # Set environment variables for the build
      env_vars = {
        'DB' => @db_type,
        'LIB_NAME' => config[:lib_name],
        'DUMMY_PATH' => template_dir.to_s
      }

      # Generate the Rails app and run all setup
      build_command = build_rake_command(config, env_vars)
      log "Running: #{build_command}"

      # Execute with environment variables
      success = system(env_vars, build_command)
      raise("Failed to build #{template_type} template") unless success
    end

    # Store metadata about the template
    write_template_metadata(template_dir, template_type, config)

    log "#{template_type} template built successfully at #{template_dir}"
  end

  def build_rake_command(config, env_vars)
    # Use the root Gemfile for core gems, local for others
    gemfile = %w[spree/core spree/api].include?(config[:lib_name]) ? ROOT.join('Gemfile') : './Gemfile'

    # Build environment variable prefix for the command
    # We pass these as rake task arguments which don't use colons in values
    rake_args = []
    rake_args << "authentication=#{config[:authentication]}"
    rake_args << "user_class=#{config[:user_class]}"
    rake_args << "admin_user_class=#{config[:admin_user_class]}" if config[:admin_user_class]
    rake_args << "install_admin=#{config[:install_admin]}"
    rake_args << "install_storefront=#{config[:install_storefront]}"
    rake_args << "javascript=#{config[:javascript]}"
    rake_args << "css=#{config[:css]}"

    # Use environment variables instead of rake arguments to avoid parsing issues with colons
    "AUTHENTICATION=#{config[:authentication]} " \
    "USER_CLASS=#{config[:user_class]} " \
    "ADMIN_USER_CLASS=#{config[:admin_user_class] || ''} " \
    "INSTALL_ADMIN=#{config[:install_admin]} " \
    "INSTALL_STOREFRONT=#{config[:install_storefront]} " \
    "JAVASCRIPT=#{config[:javascript]} " \
    "CSS=#{config[:css]} " \
    "bundle exec --gemfile=#{gemfile} rake common:build_prebuilt_app"
  end

  def write_template_metadata(template_dir, template_type, config)
    metadata = {
      'template_type' => template_type,
      'db_type' => @db_type,
      'config' => stringify_keys(config),
      'built_at' => Time.now.iso8601
    }

    File.write(template_dir.join('.prebuilt_metadata.yml'), YAML.dump(metadata))
  end

  def stringify_keys(hash)
    hash.transform_keys(&:to_s).transform_values do |v|
      v.is_a?(Hash) ? stringify_keys(v) : v
    end
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
    puts e.backtrace.first(10).join("\n") if ENV['DEBUG']
    exit 1
  end
end
