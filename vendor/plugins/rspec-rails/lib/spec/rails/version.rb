module Spec
  module Rails
    module VERSION #:nodoc:
      unless defined? MAJOR
        MAJOR  = 1
        MINOR  = 1
        TINY   = 11
        MINESCULE = 4

        STRING = [MAJOR, MINOR, TINY, MINESCULE].join('.')

        SUMMARY = "rspec-rails #{STRING}"
      end
    end
  end
end