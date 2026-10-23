# GET /r/:id?app=fidele&placement=banner  -> counts the click, then redirects to the ad target
class ClicksController < ActionController::Base
  BOT_USER_AGENT = /bot|crawl|spider|slurp|preview|facebookexternalhit|whatsapp|telegram|slack|discord|curl|wget/i

  def show
    ad = Ad.find_by(id: params[:id])
    return head(:not_found) unless ad

    unless BOT_USER_AGENT.match?(request.user_agent.to_s) || request.head?
      AdDailyStat.track!(ad_id: ad.id, kind: :click, app_key: params[:app], placement: params[:placement])
    end

    response.set_header("Cache-Control", "no-store")
    response.set_header("X-Robots-Tag", "noindex, nofollow")
    redirect_to ad.target_url, allow_other_host: true, status: :found
  end
end
