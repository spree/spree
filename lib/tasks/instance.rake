# Redefined standard Rails tasks only in instance mode
unless File.directory? "#{RAILS_ROOT}/app"
  require 'rake/testtask'
  
  ENV['SPREE_ENV_FILE'] = File.join(RAILS_ROOT, 'config', 'environment')
  
  [Dir["#{SPREE_ROOT}/vendor/rails/railties/lib/tasks/*.rake"], Dir["#{SPREE_ROOT}/vendor/plugins/rspec_on_rails/tasks/*.rake"]].flatten.each do |rake|
    lines = IO.readlines(rake)
    lines.map! do |line|
      line.gsub!('RAILS_ROOT', 'SPREE_ROOT') unless rake =~ /(misc|rspec)\.rake$/
      case rake
      when /testing\.rake$/
        line.gsub!(/t.libs << (["'])/, 't.libs << \1' + SPREE_ROOT + '/')
        line.gsub!(/t\.pattern = (["'])/, 't.pattern = \1' + SPREE_ROOT + '/')
      when /databases\.rake$/
        line.gsub!(/migrate\((["'])/, 'migrate(\1' + SPREE_ROOT + '/')
        line.sub!("db/schema.rb", "#{RAILS_ROOT}/db/schema.rb")
      when /rspec\.rake$/
        line.gsub!('RAILS_ROOT', 'SPREE_ROOT') unless line =~ /:noop/
        line.gsub!(/FileList\[(["'])/, "FileList[\\1#{SPREE_ROOT}/")
      end
      line
    end
    eval(lines.join("\n"), binding, rake)
  end
end