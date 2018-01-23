require 'digest/sha1'

module Nanoc::DataSources

  class Static < Nanoc::DataSource

    identifier :static

    def items
      # Get prefix
      prefix = config[:prefix] || 'static'

      # Get all files under prefix dir
      filenames = Dir[prefix + '/**/*'].select { |f| File.file?(f) }

      # Convert filenames to items
      filenames.map do |filename|
        attributes = {
          extension: File.extname(filename)[1..-1],
          filename: filename,
        }
        identifier = Nanoc::Identifier.new(filename[(prefix.length+1)..-1] + '/', type: :legacy)

        new_item(
          "#{Dir.pwd}/#{filename}",
          attributes,
          identifier,
          binary: true
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
