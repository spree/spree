Dir["#{File.dirname(__FILE__)}/testing_support/factories/**/*.rb"].sort.each { |f| load File.expand_path(f) }
