class MigrateTokenizedPermissions < ActiveRecord::Migration
  def concat(str1, str2)
    dbtype = Rails.configuration.database_configuration[Rails.env]['adapter'].to_sym

    case dbtype
    when :mysql, :mysql2
      "CONCAT(#{str1}, #{str2})"
    when :sqlserver
      "(#{str1} + #{str2})"
    else
      "(#{str1} || #{str2})"
    end
  end

  def up
    execute "UPDATE spree_tokenized_permissions SET permissable_type = #{concat("'Spree::'", "permissable_type")}" +
            " WHERE permissable_type NOT LIKE 'Spree::%' AND permissable_type IS NOT NULL"
  end

  def down
    execute "UPDATE spree_tokenized_permissions SET permissable_type = REPLACE(permissable_type, 'Spree::', '')" + 
            " WHERE permissable_type LIKE 'Spree::%'"
  end
end
