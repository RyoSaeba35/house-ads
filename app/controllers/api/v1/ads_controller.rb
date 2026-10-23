module Api
  module V1
    class AdsController < Api::BaseController
      CLIENT_TTL = 15.minutes

      # GET /api/v1/ads?placement=banner&app=fidele
      def index
        app_key = app_key_param
        ads = Ad.live
                .for_placement(params[:placement])
                .for_app(app_key)
                .with_attached_image
                .order(:id)
                .select { |ad| ad.image.attached? }

        expires_in 5.minutes, public: true
        render json: { ads: ads.map { |ad| serialize(ad, app_key) }, ttl: CLIENT_TTL.to_i }
      end

      # POST /api/v1/ads/:id/impression?app=fidele
      def impression
        AdDailyStat.track!(ad_id: params[:id], kind: :impression, app_key: app_key_param)
        head :no_content
      end

      private

      def serialize(ad, app_key)
        {
          id: ad.id,
          name: ad.name,
          placement: ad.placement,
          weight: ad.weight,
          label: ad.label,
          alt: ad.alt_text.presence || ad.name,
          aspect_ratio: ad.aspect_ratio,
          image_url: rails_storage_proxy_url(ad.image),
          click_url: click_url(ad, app: app_key),
          impression_url: api_v1_ad_impression_url(ad, app: app_key)
        }
      end
    end
  end
end
