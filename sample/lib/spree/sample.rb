module Spree
  module Sample
    def self.load_sample(file)

      local_path = nil
      decorator_paths = []
      $LOAD_PATH.each do |p|
        lp = File.expand_path(Pathname.new(File.join(p, '..', 'db', 'samples')) + "#{file}.rb")
        lpd = File.expand_path(Pathname.new(File.join(p, '..', 'db', 'samples')) + "#{file}_decorator.rb")
        local_path = lp if File.exists?(lp) && !lp.to_s.include?("sample/")
        decorator_paths << lpd if File.exists?(lpd)
      end

      path = local_path || File.expand_path(samples_path + "#{file}.rb")
      # Check to see if the specified file has been loaded before
      if !$LOADED_FEATURES.include?(path)
        require path
        decorator_paths.each do |dpath|
          require dpath
        end
        puts "Loaded #{file.titleize} samples"
      end
    end

    private
      def self.samples_path
        Pathname.new(File.join(File.dirname(__FILE__), '..', '..', 'db', 'samples'))
      end
  end
end
