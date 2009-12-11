
require 'rake'

SPEC = Gem::Specification.new do |s|
  s.name = "more"
  s.summary = "LESS on Rails"
  s.homepage = "http://github.com/cloudhead/more"
  s.description = <<-EOS
    More is a plugin for Ruby on Rails applications. It automatically
    parses your applications .less files through LESS and outputs CSS files.
  EOS
  s.authors = ["August Lilleaas", "Logan Raarup"]
  s.version = "0.0.4"
  s.files = FileList["README.markdown", "MIT-LICENSE", "Rakefile", "init.rb", "lib/*.rb", "rails/init.rb", "tasks/*", "test/*"]
  s.has_rdoc = true
  s.add_dependency "less"
end
