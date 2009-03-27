module Searchlogic
  module ActiveRecord
    module ConnectionAdapters # :nodoc: all
      module MysqlAdapter
        # Date / time functions
        def microseconds_sql(column_name)
          "MICROSECOND(#{column_name})"
        end
        
        def milliseconds_sql(column_name)
          "(MICROSECOND(#{column_name}) / 1000)"
        end
        
        def second_sql(column_name)
          "SECOND(#{column_name})"
        end
        
        def minute_sql(column_name)
          "MINUTE(#{column_name})"
        end
        
        def hour_sql(column_name)
          "HOUR(#{column_name})"
        end
        
        def day_of_week_sql(column_name)
          "DAYOFWEEK(#{column_name})"
        end
        
        def day_of_month_sql(column_name)
          "DAYOFMONTH(#{column_name})"
        end
        
        def day_of_year_sql(column_name)
          "DAYOFYEAR(#{column_name})"
        end
        
        def week_sql(column_name)
          "WEEK(#{column_name}, 2)"
        end
        
        def month_sql(column_name)
          "MONTH(#{column_name})"
        end
        
        def year_sql(column_name)
          "YEAR(#{column_name})"
        end
        
        # String functions
        def char_length_sql(column_name)
          "CHAR_LENGTH(#{column_name})"
        end
        
        def lower_sql(column_name)
          "LOWER(#{column_name})"
        end
        
        def ltrim_sql(column_name)
          "LTRIM(#{column_name})"
        end
        
        def md5_sql(column_name)
          "MD5(#{column_name})"
        end
        
        def rtrim_sql(column_name)
          "RTRIM(#{column_name})"
        end
        
        def trim_sql(column_name)
          "TRIM(#{column_name})"
        end
        
        def upper_sql(column_name)
          "UPPER(#{column_name})"
        end
        
        # Number functions
        def absolute_sql(column_name)
          "ABS(#{column_name})"
        end
        
        def acos_sql(column_name)
          "ACOS(#{column_name})"
        end
        
        def asin_sql(column_name)
          "ASIN(#{column_name})"
        end
        
        def atan_sql(column_name)
          "ATAN(#{column_name})"
        end
        
        def avg_sql(column_name)
          "AVG(#{column_name})"
        end
        
        def ceil_sql(column_name)
          "CEIL(#{column_name})"
        end
        
        def cos_sql(column_name)
          "COS(#{column_name})"
        end
        
        def cot_sql(column_name)
          "COT(#{column_name})"
        end
        
        def degrees_sql(column_name)
          "DEGREES(#{column_name})"
        end
        
        def exp_sql(column_name)
          "EXP(#{column_name})"
        end
        
        def floor_sql(column_name)
          "FLOOR(#{column_name})"
        end
        
        def hex_sql(column_name)
          "HEX(#{column_name})"
        end
        
        def ln_sql(column_name)
          "LN(#{column_name})"
        end
        
        def log_sql(column_name)
          "LOG(#{column_name})"
        end
        
        def log2_sql(column_name)
          "LOG2(#{column_name})"
        end
        
        def log10_sql(column_name)
          "LOG10(#{column_name})"
        end
        
        def octal_sql(column_name)
          "OCT(#{column_name})"
        end
        
        def radians_sql(column_name)
          "RADIANS(#{column_name})"
        end
        
        def round_sql(column_name)
          "ROUND(#{column_name})"
        end
        
        def sign_sql(column_name)
          "SIGN(#{column_name})"
        end
        
        def sin_sql(column_name)
          "SIN(#{column_name})"
        end
        
        def square_root_sql(column_name)
          "SQRT(#{column_name})"
        end
        
        def tan_sql(column_name)
          "TAN(#{column_name})"
        end
      end
    end
  end
end

::ActiveRecord::ConnectionAdapters::MysqlAdapter.send(:include, Searchlogic::ActiveRecord::ConnectionAdapters::MysqlAdapter)