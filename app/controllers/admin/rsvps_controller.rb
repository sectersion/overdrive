require "csv"

module Admin
  class RsvpsController < ApplicationController
    before_action :require_admin

    def index
      @stats = Rsvp.stats
      @by_ref = Rsvp.where.not(ref: nil).group(:ref).order(count_all: :desc).count
      @by_heard = Rsvp.where.not(heard_from: [ nil, "" ]).group(:heard_from).count
      @rsvps = Rsvp.includes(:user).order(created_at: :desc)

      respond_to do |format|
        format.html { @rsvps = @rsvps.limit(500) }
        format.csv { send_data to_csv(@rsvps), filename: "overdrive-rsvps-#{Date.current}.csv" }
      end
    end

    private

    def require_admin
      return if current_user&.admin?
      return redirect_to(root_path, alert: "That account isn't an Overdrive admin.") if current_user
      render "admin/sign_in", formats: :html, status: :unauthorized
    end

    def to_csv(rsvps)
      CSV.generate do |csv|
        csv << %w[created_at source linked email hca_id slack_id name verification_status building heard_from ref]
        rsvps.find_each do |r|
          u = r.user
          csv << [ r.created_at.iso8601, r.source, r.linked?, r.email || u&.email, u&.hca_id, u&.slack_id,
                   u&.display_name, u&.verification_status, r.building, r.heard_from, r.ref ]
        end
      end
    end
  end
end
