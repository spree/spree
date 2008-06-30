module Spec
  module Rails
    module VERSION #:nodoc:
      unless defined? MAJOR
        MAJOR  = 1
        MINOR  = 1
        TINY   = 4
        RELEASE_CANDIDATE = nil

        BUILD_TIME_UTC = 20080628203842

        STRING = [MAJOR, MINOR, TINY].join('.')
        TAG = "REL_#{[MAJOR, MINOR, TINY, RELEASE_CANDIDATE].compact.join('_')}".upcase.gsub(/\.|-/, '_')
        FULL_VERSION = "#{[MAJOR, MINOR, TINY, RELEASE_CANDIDATE].compact.join('.')} (build #{BUILD_TIME_UTC})"

        NAME   = "RSpec-Rails"
        URL    = "http://github.com/dchelimsky/rspec-rails"  

        DESCRIPTION = "#{NAME}-#{FULL_VERSION} - BDD for Ruby on Rails\n#{URL}"
      end
    end
  end
end

# Verify that the plugin has the same revision as RSpec
if Spec::Rails::VERSION::BUILD_TIME_UTC != Spec::VERSION::BUILD_TIME_UTC
  raise <<-EOF

############################################################################
Your RSpec on Rails plugin is incompatible with your installed RSpec.

RSpec          : #{Spec::VERSION::BUILD_TIME_UTC}
RSpec on Rails : #{Spec::Rails::VERSION::BUILD_TIME_UTC}

Make sure your RSpec on Rails plugin is compatible with your RSpec gem.
See http://rspec.rubyforge.org/documentation/rails/install.html for details.
############################################################################
EOF
end
