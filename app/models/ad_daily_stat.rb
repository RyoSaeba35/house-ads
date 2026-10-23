class AdDailyStat < ApplicationRecord
  UNKNOWN_APP = "unknown".freeze
  OTHER_PLACEMENT = "other".freeze
  SUMS = [
    Arel.sql("COALESCE(SUM(impressions), 0)"),
    Arel.sql("COALESCE(SUM(clicks), 0)")
  ].freeze

  belongs_to :ad

  def self.normalize_app_key(key)
    key.to_s.downcase.gsub(/[^a-z0-9_-]/, "").first(40).presence || UNKNOWN_APP
  end

  def self.normalize_placement(value)
    Ad.valid_placement(value) || OTHER_PLACEMENT
  end

  # Atomic counter upsert: one row per ad, per day, per app, per placement.
  def self.track!(ad_id:, kind:, app_key:, placement:)
    impressions, clicks = kind.to_s == "click" ? [0, 1] : [1, 0]
    values = [ad_id.to_i, Time.zone.today, normalize_app_key(app_key), normalize_placement(placement), impressions, clicks]
    sql = sanitize_sql_array([<<~SQL, *values])
      INSERT INTO ad_daily_stats (ad_id, day, app_key, placement, impressions, clicks, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, NOW(), NOW())
      ON CONFLICT (ad_id, day, app_key, placement) DO UPDATE SET
        impressions = ad_daily_stats.impressions + EXCLUDED.impressions,
        clicks = ad_daily_stats.clicks + EXCLUDED.clicks,
        updated_at = NOW()
    SQL
    connection.execute(sql)
    true
  rescue ActiveRecord::InvalidForeignKey
    false
  end

  def self.totals(scope)
    scope.pick(*SUMS).map(&:to_i)
  end

  # [[day, impressions, clicks], ...] with zero-filled missing days
  def self.daily_series(scope, from:, to:)
    rows = scope.group(:day).pluck(:day, *SUMS).to_h { |day, imp, clk| [day, [imp.to_i, clk.to_i]] }
    (from..to).map { |day| [day, *rows.fetch(day, [0, 0])] }
  end

  # [[key, impressions, clicks], ...] sorted by impressions desc
  def self.breakdown(scope, column)
    scope.group(column)
         .order(Arel.sql("COALESCE(SUM(impressions), 0) DESC"))
         .pluck(column, *SUMS)
         .map { |key, imp, clk| [key, imp.to_i, clk.to_i] }
  end
end
