module Admin
  class BaseController < ApplicationController
    layout "admin"
    before_action :authenticate_admin!

    private

    def authenticate_admin!
      user = ENV["ADMIN_USER"].presence || "admin"
      password = ENV["ADMIN_PASSWORD"].presence
      password ||= "admin" unless Rails.env.production?

      if password.nil?
        render plain: "ADMIN_PASSWORD is not set on the server.", status: :service_unavailable
        return
      end

      authenticate_or_request_with_http_basic("House Ads") do |given_user, given_password|
        ActiveSupport::SecurityUtils.secure_compare(given_user, user) &
          ActiveSupport::SecurityUtils.secure_compare(given_password, password)
      end
    end
  end
end
