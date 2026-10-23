module Admin
  class DocsController < BaseController
    def show
      @base = request.base_url
      @sample_ad = Ad.live.with_all_images.order(:id).first
      @app_keys = AdDailyStat.distinct.order(:app_key).pluck(:app_key) - [AdDailyStat::UNKNOWN_APP]
    end
  end
end
