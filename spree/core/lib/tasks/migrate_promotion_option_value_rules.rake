namespace :spree do
  namespace :upgrade do
    desc 'Rewrite Option Value promotion rules from join-row ids to option value ids'
    task migrate_promotion_option_value_rules: :environment do
      total = Spree::Promotion::Rules::OptionValue.count
      converted = 0

      Spree::Promotion::Rules::OptionValue.find_each do |rule|
        raw = Array(rule.preferred_eligible_values).map(&:to_s).compact_blank
        next if raw.empty?

        mapped = raw.filter_map do |id|
          if (join_row = Spree::OptionValueVariant.find_by(id: id))
            join_row.option_value_id.to_s
          elsif Spree::OptionValue.exists?(id)
            id
          end
        end.uniq

        next if mapped == raw

        rule.update!(preferred_eligible_values: mapped)
        converted += 1
      end

      puts "Option Value promotion rules: #{converted}/#{total} converted to option value ids"
    end
  end
end
