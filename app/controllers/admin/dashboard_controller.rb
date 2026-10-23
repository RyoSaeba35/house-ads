module Admin
  class DashboardController < BaseController
    PERIODS = %w[7 30 90].freeze

    def show
      @period = PERIODS.include?(params[:period]) ? params[:period] : "30"
      @to = Time.zone.today
      @from = @to - (@period.to_i - 1)

      scope = AdDailyStat.where(day: @from..@to)
      @totals = AdDailyStat.totals(scope)
      @series = AdDailyStat.daily_series(scope, from: @from, to: @to)
      @by_ad = AdDailyStat.breakdown(scope, :ad_id)
      @by_app = AdDailyStat.breakdown(scope, :app_key)
      @ads = Ad.with_attached_image.where(id: @by_ad.map(&:first)).index_by(&:id)
      @live_count = Ad.live.count
    end
  end
end
