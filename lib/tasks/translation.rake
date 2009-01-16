namespace :spree do
  namespace :translation do
    task :sync => :environment do
      language_root = "#{SPREE_ROOT}/config/locales/"
      (dummy_comments, words) = read_file("#{language_root}en-US.yml", 'en-US')
      Dir["#{SPREE_ROOT}/config/locales/*.yml"].each do |filename|
        next if filename.match('_rails')
        basename = File.basename(filename, '.yml')
        (comments, other) = read_file(filename, basename)
        words.each { |k,v| other[k] ||= '' }                     #Initializing hash variable as empty if it does not exist
        write_file(filename, basename, comments, other)
      end
    end
  end
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
    (key, value) = w.split(':')
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
