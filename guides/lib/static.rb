require 'digest/sha1'

module Nanoc3::DataSources

  class Static < Nanoc3::DataSource

    identifier :static

    def items
      # Get prefix
      prefix = config[:prefix] || 'static'

      # Get all files under prefix dir
      filenames = Dir[prefix + '/**/*'].select { |f| File.file?(f) }

      # Convert filenames to items
      filenames.map do |filename|
        attributes = {
          :extension => File.extname(filename)[1..-1],
          :filename  => filename,
        }
        identifier = filename[(prefix.length+1)..-1] + '/'

        mtime      = File.mtime(filename)
        checksum   = checksum_for(filename)

        Nanoc3::Item.new(
          filename,
          attributes,
          identifier,
          :binary => true, :mtime => mtime, :checksum => checksum
        )
      end
    end

  private

    # Returns a checksum of the given filenames
    # TODO un-duplicate this somewhere
    def checksum_for(*filenames)
      filenames.flatten.map do |filename|
        digest = Digest::SHA1.new
        File.open(filename, 'r') do |io|
          until io.eof
            data = io.readpartial(2**10)
            digest.update(data)
          end
        end
        digest.hexdigest
      end.join('-')
    end

  end

end
