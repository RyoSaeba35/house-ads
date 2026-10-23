module Admin
  class AdsController < BaseController
    PERIODS = %w[7 30 90].freeze
    FIELDS = (%i[name target_url weight active starts_at ends_at app_keys_list target_app_key label alt_text] +
              Ad::PLACEMENTS.flat_map { |p| [:"#{p}_enabled", :"#{p}_image"] }).freeze

    before_action :set_ad, only: %i[show edit update destroy toggle]

    def index
      @ads = Ad.with_all_images.order(active: :desc, created_at: :desc)
      @totals = AdDailyStat.breakdown(AdDailyStat.all, :ad_id).to_h { |id, imp, clk| [id, [imp, clk]] }
    end

    def show
      @period = PERIODS.include?(params[:period]) ? params[:period] : "30"
      @to = Time.zone.today
      @from = @to - (@period.to_i - 1)

      scope = @ad.daily_stats.where(day: @from..@to)
      @totals = AdDailyStat.totals(scope)
      @series = AdDailyStat.daily_series(scope, from: @from, to: @to)
      @by_placement = AdDailyStat.breakdown(scope, :placement)
      @by_app = AdDailyStat.breakdown(scope, :app_key)
      @all_time = AdDailyStat.totals(@ad.daily_stats)
    end

    def new
      @ad = Ad.new(banner_enabled: true)
    end

    def create
      @ad = Ad.new(ad_params)
      if @ad.save
        redirect_to admin_ad_path(@ad), notice: "Ad created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @ad.update(ad_params)
        redirect_to admin_ad_path(@ad), notice: "Ad updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def toggle
      @ad.update_columns(active: !@ad.active, updated_at: Time.current)
      redirect_back_or_to admin_ads_path, notice: @ad.active? ? "Ad activated." : "Ad paused."
    end

    def destroy
      @ad.destroy
      redirect_to admin_ads_path, notice: "Ad deleted."
    end

    private

    def set_ad
      @ad = Ad.with_all_images.find(params[:id])
    end

    # Empty file fields keep the current image.
    def ad_params
      permitted = params.expect(ad: FIELDS)
      Ad::PLACEMENTS.each do |placement|
        key = :"#{placement}_image"
        permitted.delete(key) if permitted[key].blank?
      end
      permitted
    end
  end
end
