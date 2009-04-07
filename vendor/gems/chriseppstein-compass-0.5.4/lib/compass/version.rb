module Compass
  module Version
    # Returns a hash representing the version.
    # The :major, :minor, and :teeny keys have their respective numbers.
    # The :string key contains a human-readable string representation of the version.
    # If checked out from Git,
    # the :rev key will have the revision hash.
    #
    # This method swiped from Haml and then modified, some credit goes to Nathan Weizenbaum
    attr_writer :version
    def version
      return @version if defined?(@version)

      read_version_file
      parse_version

      if r = revision
        @version[:rev] = r
        @version[:string] << " [#{r[0...7]}]"
      end

      @version
    end

    protected

    def scope(file) # :nodoc:
      File.join(File.dirname(__FILE__), '..', '..', file)
    end

    def read_version_file
      @version = {
        :string => File.read(scope('VERSION')).strip
      }
    end

    def parse_version
      dotted_string, @version[:label] = @version[:string].split(/-/, 2)
      numbers = dotted_string.split('.').map { |n| n.to_i }
      [:major, :minor, :teeny].zip(numbers).each do |attr, value|
        @version[attr] = value
      end
    end

    def revision
      revision_from_git || revision_from_file
    end

    def revision_from_file
      if File.exists?(scope('REVISION'))
        rev = File.read(scope('REVISION')).strip
        rev = nil if rev !~ /[a-f0-9]+/
      end
    end

    def revision_from_git
      if File.exists?(scope('.git/HEAD'))
        rev = File.read(scope('.git/HEAD')).strip
        if rev =~ /^ref: (.*)$/
          rev = File.read(scope(".git/#{$1}")).strip
        end
      end
    end

  end
end
