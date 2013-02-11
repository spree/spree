module Spree
  module Sample
    def self.load_sample(file)
      path = File.expand_path(samples_path + "#{file}.rb")
      # Check to see if the specified file has been loaded before
      if !$LOADED_FEATURES.include?(path)
        require path
        puts "Loaded #{file.titleize} samples"
      end
    end

    private
      def self.samples_path
        Pathname.new(File.join(File.dirname(__FILE__), '..', '..', 'db', 'samples'))
      end
  end
end
