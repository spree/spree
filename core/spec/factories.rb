Dir["#{File.dirname(__FILE__)}/factories/**"].each do |f|
  fp =  File.expand_path(f)
  require fp
end

