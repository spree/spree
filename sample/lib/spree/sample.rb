module Spree
  module Sample
    def self.load_sample(file)
      # If file exists within application it takes precedence.
      path = if File.exist?(File.join(Rails.root, 'db', 'samples', "#{file}.rb"))
               File.expand_path(File.join(Rails.root, 'db', 'samples', "#{file}.rb"))
             else
               # Otherwise we will use this gems default file.
               File.expand_path(samples_path + "#{file}.rb")
             end
      # Check to see if the specified file has been loaded before
      unless $LOADED_FEATURES.include?(path)
        require path
        puts "Loaded #{file.titleize} samples"
      end
    end

    def self.samples_path
      Pathname.new(File.join(File.dirname(__FILE__), '..', '..', 'db', 'samples'))
    end
  end
end
