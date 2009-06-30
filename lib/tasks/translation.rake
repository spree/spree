namespace :spree do
  namespace :i18n do
    #Define locales root
    language_root = "#{SPREE_ROOT}/config/locales/"

    task :sync => :environment do
      words = get_translation_keys(language_root)
      Dir["#{language_root}*.yml"].each do |filename|
        next if filename.match('_rails')
        basename = File.basename(filename, '.yml')
        (comments, other) = read_file(filename, basename)
        words.each { |k,v| other[k] ||= words[k] }                     #Initializing hash variable as empty if it does not exist
        other.delete_if { |k,v| !words[k] }                            #Remove if not defined in en-US.yml
        write_file(filename, basename, comments, other)
      end
    end

    task :new => :environment do
      if !ENV['LOCALE'] || ENV['LOCALE'] == ''
        print "You must provide a valid LOCALE value, for example:\nrake spree:i18:new LOCALE=pt-PT\n"
        exit
      end
      write_file("#{language_root}/#{ENV['LOCALE']}.yml", "#{ENV['LOCALE']}", '---', get_translation_keys(language_root))
      print "Also, download the rails translation from: http://github.com/svenfuchs/rails-i18n/tree/master/rails/locale\n"
    end
  end
end

#Retrieve US word set
def get_translation_keys(language_root)
  (dummy_comments, words) = read_file("#{language_root}en-US.yml", 'en-US')
  words
end

#Retrieve comments, translation data in hash form
def read_file(filename, basename)
  (comments, data) = IO.read(filename).split(/\n#{basename}:\s*\n/)   #Add error checking for failed file read?
  return comments, create_hash(data, basename)
end

#Creates hash of translation data
def create_hash(data, basename)
  words = Hash.new
  return words if !data
  parent = Array.new
  previous_key = 'base'
  data.split("\n").each do |w|
    next if w.strip.blank?
    (key, value) = w.split(':', 2)
    value ||= ''
    shift = (key =~ /\w/)/2 - parent.size                             #Determine level of current key in comparison to parent array
    key = key.sub(/^\s+/,'')
    parent << previous_key if shift > 0                               #If key is child of previous key, add previous key as parent
    (shift*-1).times { parent.pop } if shift < 0                      #If key is not related to previous key, remove parent keys
    previous_key = key                                                #Track key in case next key is child of this key
    words[parent.join(':')+':'+key] = value
  end
  words
end

#Writes to file from translation data hash structure
def write_file(filename,basename,comments,words)
  File.open(filename, "w") do |log|
    log.puts(comments+"\n"+basename+": \n")
    words.sort.each do |k,v|
      keys = k.split(':')
      (keys.size-1).times { keys[keys.size-1] = '  ' + keys[keys.size-1] }   #Add indentation for children keys
      log.puts(keys[keys.size-1]+':'+v+"\n")
    end
  end
end
