class RsvpsController < ApplicationController
  rate_limit to: 5, within: 10.minutes, only: :create, with: -> { redirect_to root_path(anchor: "rsvp"), alert: "Slow down! Try again in a few minutes." }

  # Email RSVP. Unconfirmed until linked to a Hack Club account.
  def create
    unless Turnstile.verify(params["cf-turnstile-response"], remote_ip: request.remote_ip)
      return redirect_to root_path(anchor: "rsvp"), alert: "Couldn't verify you're human. Please try again."
    end

    email = rsvp_params[:email].to_s.strip.downcase
    # Already RSVP'd: either by this email, or via a Hack Club account with this email.
    @rsvp = Rsvp.find_by(email:) || User.find_by(email:)&.rsvp || Rsvp.new(email:)
    if @rsvp.persisted?
      remember_email_rsvp(@rsvp)
      return redirect_to thanks_rsvp_path, notice: "You've already RSVP'd with that email. You're all set!"
    end

    @rsvp.assign_attributes(rsvp_params.merge(
      source: "email",
      ref: session[:ref],
      ip_address: request.remote_ip,
      user_agent: request.user_agent.to_s.first(255)
    ))

    if @rsvp.save
      remember_email_rsvp(@rsvp)
      redirect_to thanks_rsvp_path
    else
      @stats = Rsvp.stats
      @my_rsvp = nil
      render "pages/home", status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique
    redirect_to thanks_rsvp_path
  end

  def thanks
    @my_rsvp = current_user&.rsvp || remembered_rsvp
    redirect_to root_path(anchor: "rsvp") unless @my_rsvp
  end

  private

  def rsvp_params
    params.expect(rsvp: [ :email, :building, :heard_from ])
  end
end
