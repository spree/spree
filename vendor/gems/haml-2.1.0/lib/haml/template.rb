require 'haml/engine'

module Haml
  class Template
    class << self
      @@options = {}

      # Gets various options for Haml. See README.rdoc for details.
      def options
        @@options
      end

      # Sets various options for Haml. See README.rdoc for details.
      def options=(value)
        @@options = value
      end
    end
  end
end

# Decide how we want to load Haml into Rails.
# Patching was necessary for versions <= 2.0.1,
# but we can make it a normal handler for higher versions.
if defined?(ActionView::TemplateHandler)
  require 'haml/template/plugin'
else
  require 'haml/template/patch'
end

if defined?(RAILS_ROOT)
  # Update init.rb to the current version
  # if it's out of date.
  #
  # We can probably remove this as of v1.9,
  # because the new init file is sufficiently flexible
  # to not need updating.
  rails_init_file = File.join(RAILS_ROOT, 'vendor', 'plugins', 'haml', 'init.rb')
  haml_init_file = Haml.scope('init.rb')
  begin
    if File.exists?(rails_init_file)
      require 'fileutils'
      FileUtils.cp(haml_init_file, rails_init_file) unless FileUtils.cmp(rails_init_file, haml_init_file)
    end
  rescue SystemCallError
    warn <<END
HAML WARNING:
#{rails_init_file} is out of date and couldn't be automatically updated.
Please run `haml --rails #{File.expand_path(RAILS_ROOT)}' to update it.
END
  end
end
