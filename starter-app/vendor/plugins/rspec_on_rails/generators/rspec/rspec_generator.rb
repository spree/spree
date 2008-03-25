require 'rbconfig'

# This generator bootstraps a Rails project for use with RSpec
class RspecGenerator < Rails::Generator::Base
  DEFAULT_SHEBANG = File.join(Config::CONFIG['bindir'],
                              Config::CONFIG['ruby_install_name'])

  def initialize(runtime_args, runtime_options = {})
    super
  end

  def manifest
    record do |m|
      script_options     = { :chmod => 0755, :shebang => options[:shebang] == DEFAULT_SHEBANG ? nil : options[:shebang] }

      m.directory 'spec'
      m.template  'spec_helper.rb',                'spec/spec_helper.rb'
      m.file      'spec.opts',                     'spec/spec.opts'
      m.file      'rcov.opts',                     'spec/rcov.opts'
      m.file      'script/spec_server',            'script/spec_server', script_options
      m.file      'script/spec',                   'script/spec',        script_options

      m.directory 'stories'
      m.file      'all_stories.rb',                'stories/all.rb'
      m.file      'stories_helper.rb',             'stories/helper.rb'
    end
  end

protected

  def banner
    "Usage: #{$0} rspec"
  end

end
