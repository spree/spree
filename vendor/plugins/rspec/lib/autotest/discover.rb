Autotest.add_discovery do
  "rspec" if File.exist?('spec')
end
