# frozen_string_literal: true

# 5.6 → 6.0: rewrite Option Value promotion rules that still store
# Spree::OptionValueVariant join-row ids into stable Spree::OptionValue ids.
module Spree
  # Rewrites legacy join-row ids in Option Value promotion rules. Ambiguous or
  # unresolvable ids are reported and left untouched so operators can review
  # affected rules before continuing.
  class PromotionOptionValueRulesMigrator
    Issue = Data.define(:rule_id, :raw_id, :kind)

    # @return [Integer] number of rules rewritten
    attr_reader :converted

    # @return [Array<Issue>] ids that could not be mapped
    attr_reader :issues

    # @param skip_failed [Boolean] when true, report issues but do not abort
    def initialize(skip_failed: false)
      @skip_failed = skip_failed
      @converted = 0
      @issues = []
    end

    # @return [void]
    def call
      total = Spree::Promotion::Rules::OptionValue.count

      Spree::Promotion::Rules::OptionValue.find_each do |rule|
        migrate_rule(rule)
      end

      report(total)
    end

    private

    # @param rule [Spree::Promotion::Rules::OptionValue]
    # @return [void]
    def migrate_rule(rule)
      raw = Array(rule.preferred_eligible_values).map(&:to_s).compact_blank
      return if raw.empty?

      mapped = []
      rule_issues = []

      raw.each do |raw_id|
        resolution = resolve_id(raw_id)
        case resolution
        in :ambiguous
          rule_issues << Issue.new(rule_id: rule.id, raw_id: raw_id, kind: :ambiguous)
        in :unresolved
          rule_issues << Issue.new(rule_id: rule.id, raw_id: raw_id, kind: :unresolved)
        in String
          mapped << resolution
        end
      end

      if rule_issues.any?
        @issues.concat(rule_issues)
        return
      end

      mapped.uniq!
      return if mapped == raw

      rule.update!(preferred_eligible_values: mapped)
      @converted += 1
    end

    # @param raw_id [String]
    # @return [String, :ambiguous, :unresolved]
    def resolve_id(raw_id)
      join_row = Spree::OptionValueVariant.find_by(id: raw_id)
      option_value = Spree::OptionValue.exists?(raw_id)

      if join_row && option_value
        :ambiguous
      elsif join_row
        join_row.option_value_id.to_s
      elsif option_value
        raw_id
      else
        :unresolved
      end
    end

    # @param total [Integer]
    # @return [void]
    def report(total)
      puts "Option Value promotion rules: #{@converted}/#{total} converted to option value ids"

      return if @issues.empty?

      puts "  #{@issues.size} eligible value id(s) could not be migrated:"
      @issues.each do |issue|
        puts "  rule ##{issue.rule_id} id #{issue.raw_id}: #{issue.kind}"
      end

      if @skip_failed
        report_skip_notice
        return
      end

      abort '  Re-run after fixing affected rules, or pass SKIP_FAILED_ROWS=true to continue without converting them.'
    end

    # @return [void]
    def report_skip_notice
      puts '  Continuing anyway (SKIP_FAILED_ROWS=true).'
    end
  end
end

namespace :spree do
  namespace :upgrade do
    desc 'Rewrite Option Value promotion rules from join-row ids to option value ids'
    task migrate_promotion_option_value_rules: :environment do
      Spree::PromotionOptionValueRulesMigrator.new(
        skip_failed: ENV['SKIP_FAILED_ROWS'] == 'true'
      ).call
    end
  end
end
