module Api
  module V1
    class AdsController < Api::BaseController
      CLIENT_TTL = 15.minutes

      # GET /api/v1/ads?placement=banner&app=fidele
      # Returns only ads where that placement is ticked and has an image.
      def index
        app_key = app_key_param
        placement = Ad.valid_placement(params[:placement].presence || "banner")

        ads = if placement
                Ad.live
                  .for_placement(placement)
                  .for_app(app_key)
                  .public_send(:"with_attached_#{placement}_image")
                  .order(:id)
                  .select { |ad| ad.serves?(placement) }
              else
                []
              end

        expires_in 5.minutes, public: true
        render json: { ads: ads.map { |ad| serialize(ad, placement, app_key) }, ttl: CLIENT_TTL.to_i }
      end

      # POST /api/v1/ads/:id/impression?app=fidele&placement=banner
      def impression
        AdDailyStat.track!(ad_id: params[:id], kind: :impression, app_key: app_key_param, placement: params[:placement])
        head :no_content
      end

      private

      def serialize(ad, placement, app_key)
        tracking = { app: app_key, placement: placement }
        {
          id: ad.id,
          name: ad.name,
          placement: placement,
          weight: ad.weight,
          label: ad.label,
          alt: ad.alt_text.presence || ad.name,
          aspect_ratio: ad.aspect_ratio(placement),
          image_url: rails_storage_proxy_url(ad.image_for(placement)),
          click_url: click_url(ad, **tracking),
          impression_url: api_v1_ad_impression_url(ad, **tracking)
        }
      end
    end
  end
end
