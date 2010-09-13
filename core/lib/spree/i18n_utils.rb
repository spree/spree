require 'rails'

module Spree
  module I18nUtils

    # #Retrieve comments, translation data in hash form
    def read_file(filename, basename)
      (comments, data) = IO.read(filename).split(/\n#{basename}:\s*\n/)   #Add error checking for failed file read?
      return comments, create_hash(data)
    end

    #Creates hash of translation data
    def create_hash(data)
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
    def write_file(filename,basename,comments,words,comment_values=true, fallback_values={})
      File.open(filename, "w") do |log|
        log.puts(comments+"\n"+basename+": \n")
        words.sort.each do |k,v|
          keys = k.split(':')
          (keys.size-1).times { keys[keys.size-1] = '  ' + keys[keys.size-1] }   #Add indentation for children keys
          value = v.strip
          value = ("#" + value) if comment_values and not value.blank?
          log.puts "#{keys[keys.size-1]}: #{value}\n"
        end
      end
    end

  end
end