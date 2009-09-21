# copy the assets from extensions public dir into #{RAILS_ROOT}/public
destination = "#{RAILS_ROOT}/public"
paths_to_mirror = Spree::ExtensionLoader.instance.load_extension_roots

paths_to_mirror.each do |extension_path|
  source = "#{extension_path}/public"
  if File.directory?(source)
    begin
      RAILS_DEFAULT_LOGGER.info "INFO: Mirroring assets from #{source} to #{destination}"
      Spree::FileUtilz.mirror_files(source, destination)
    rescue LoadError, NameError => e
      $stderr.puts "Could not copy extension assets from : #{source}.\n#{e.inspect}"
      nil
    end
  end
end