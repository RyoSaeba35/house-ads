module Api
  class BaseController < ActionController::API
    before_action :set_cors_headers

    def preflight
      head :no_content
    end

    private

    def set_cors_headers
      response.set_header("Access-Control-Allow-Origin", "*")
      response.set_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
      response.set_header("Access-Control-Allow-Headers", "Content-Type, Accept")
      response.set_header("Access-Control-Max-Age", "86400")
    end

    def app_key_param
      AdDailyStat.normalize_app_key(params[:app])
    end
  end
end
