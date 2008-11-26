class AdditionalPaperclipRefactor < ActiveRecord::Migration
  def self.up

    change_table :assets do |t|
      # remove another defunct attachment_fu column
      t.remove :parent_id
      # drop extraneous records for the thumbnails (paperclip knows about these automatically - nice!)
      execute "DELETE FROM assets WHERE viewable_id IS NULL"
      # provide a default value for the type field 
      execute "UPDATE assets SET type = 'Image' WHERE type IS NULL"
    end

    # move legacy images to the new directory structure
    puts "Copying legacy assets ..."
    Image.all.each do |image|
      sizes = %w{mini original product small}
      sizes.each do |size| 
        target_dir = "#{RAILS_ROOT}/public/assets/products/#{image.id}/#{size}" 
        FileUtils.mkdir_p target_dir
        subdir = image.id.to_s.rjust(4, '0')
        # note: not sure where the 0000 comes from with attachment_fu but it seems ok to hardcode it
        filename = image.attachment.original_filename
        unless size == "original"
          filename = filename.gsub(".", "_#{size}.")
        end
        source = "#{RAILS_ROOT}/public/images/products/0000/#{subdir}/#{filename}"
        FileUtils.cp source, target_dir
        FileUtils.mv "#{target_dir}/#{filename}", "#{target_dir}/#{image.attachment.original_filename}" unless size == "original"
      end
    end
    puts "Finished."
  end

  def self.down
    # no going back!
  end
end
