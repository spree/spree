require 'spec_helper'

# Tripwire for the store-scoped cache-key constraint
# (docs/plans/6.0-store-context-and-first-run-setup.md): a cache entry whose
# key omits the store leaks one store's data into another's responses the
# moment two stores share a deployment. Every Rails.cache call site in core
# and api must either build its key from the store (or a store-scoped
# record's cache_key_with_version) or appear in the reviewed allowlist below
# with the reason it is global by design.
#
# When this spec fails on a call site you added: include the store in the
# key, or — only if the data is genuinely installation-wide — add an
# allowlist entry with a justification.
RSpec.describe 'Store-scoped cache keys' do
  CACHE_CALL = /Rails\.cache\.(?:fetch|read|write|delete)\b/
  # A call line counts as store-scoped when the key expression visibly
  # carries the store or a record identity (record cache keys embed globally
  # unique ids, so they cannot collide across stores).
  SCOPED_HINT = /cache_key_with_version|current_store|store\.id|store_id/

  # path (relative to the spree/ directory) => justification. Reviewed
  # entries only — every reason must say why the cached data is safe to
  # share across stores. Note the granularity: an entry covers its whole
  # file, so a NEW cache call added to an allowlisted file passes silently —
  # when touching one of these files, re-review its calls.
  ALLOWLIST = {
    'core/app/models/spree/authentication/strategies/oidc_strategy.rb' =>
      'JWKS + discovery documents are per identity provider, keyed by the ' \
      'provider\'s configured cache_key_prefix; providers are application-level ' \
      'configuration, not store data.',
    'api/app/controllers/spree/api/v3/store/products/filters_controller.rb' =>
      'filters_cache_key embeds current_store.id, currency, locale and the ' \
      'catalog fingerprint — scoped, just built outside the call line.',
    'api/app/controllers/concerns/spree/api/v3/rate_limit_headers.rb' =>
      'Rate-limit budgets are per credential by design: API keys are ' \
      'store-bound, and a staff JWT\'s budget deliberately spans stores.',
    'api/app/controllers/concerns/spree/api/v3/idempotent.rb' =>
      'idempotency_cache_key partitions by credential AND the resolved ' \
      'store, so replays cannot cross stores.',
  }.freeze

  SPREE_ROOT = File.expand_path('../../../../..', __dir__)

  # Computed once at load — both examples read it, and the glob + scan over
  # two gem trees is the expensive part of this spec.
  CALL_SITES = Dir.glob(File.join(SPREE_ROOT, 'spree', '{core,api}', '{app,lib}', '**', '*.rb')).flat_map do |file|
    content = File.read(file)
    next [] unless content.include?('Rails.cache')

    relative = file.delete_prefix("#{SPREE_ROOT}/spree/")
    content.each_line.with_index(1).filter_map do |line, line_number|
      next unless line.match?(CACHE_CALL)

      { file: relative, line: line_number, source: line.strip }
    end
  end.freeze

  def call_sites
    CALL_SITES
  end

  it 'every Rails.cache call site is store-scoped or allowlisted with a reason' do
    unaccounted = call_sites.reject do |site|
      site[:source].match?(SCOPED_HINT) || ALLOWLIST.key?(site[:file])
    end

    expect(unaccounted).to be_empty, lambda {
      list = unaccounted.map { |s| "  #{s[:file]}:#{s[:line]}  #{s[:source]}" }.join("\n")
      "Cache call sites without a store-scoped key or an allowlist entry:\n#{list}\n\n" \
        'Include the store (or a record cache_key_with_version) in the key, or add a ' \
        "reviewed allowlist entry in #{__FILE__} explaining why the data is global."
    }
  end

  it 'carries no stale allowlist entries' do
    files_with_calls = call_sites.map { |site| site[:file] }.uniq

    stale = ALLOWLIST.keys - files_with_calls
    expect(stale).to be_empty,
                     "Allowlisted files no longer contain cache calls — remove them: #{stale.join(', ')}"
  end
end
