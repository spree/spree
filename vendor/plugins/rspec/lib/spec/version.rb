module Spec
  module VERSION
    unless defined? MAJOR
      MAJOR  = 1
      MINOR  = 1
      TINY   = 4
      RELEASE_CANDIDATE = nil

      BUILD_TIME_UTC = 20080628203842

      STRING = [MAJOR, MINOR, TINY].join('.')
      TAG = "REL_#{[MAJOR, MINOR, TINY, RELEASE_CANDIDATE].compact.join('_')}".upcase.gsub(/\.|-/, '_')
      FULL_VERSION = "#{[MAJOR, MINOR, TINY, RELEASE_CANDIDATE].compact.join('.')} (build #{BUILD_TIME_UTC})"

      NAME   = "RSpec"
      URL    = "http://rspec.rubyforge.org/"  
    
      DESCRIPTION = "#{NAME}-#{FULL_VERSION} - BDD for Ruby\n#{URL}"
    end
  end
end

