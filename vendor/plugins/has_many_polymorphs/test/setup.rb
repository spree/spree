
# Setup integration system for the integration suite

Dir.chdir "#{File.dirname(__FILE__)}/integration/app/" do
  Dir.chdir "vendor/plugins" do
    system("rm has_many_polymorphs; ln -s ../../../../../ has_many_polymorphs")
  end

  system "rake db:drop   --trace RAILS_GEM_VERSION=2.2.2 "
  system "rake db:create --trace RAILS_GEM_VERSION=2.2.2 "
  system "rake db:migrate --trace"
  system "rake db:fixtures:load --trace"  
end

