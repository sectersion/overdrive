class SessionsController < ApplicationController
  # GET /auth/hack_club/callback
  def create
    auth = request.env["omniauth.auth"]
    intent = request.env.dig("omniauth.params", "intent")
    user = User.from_hca_identity(auth.extra["identity"])

    reset_session_keeping_ref
    session[:user_id] = user.id

    if intent == "admin"
      return redirect_to(user.admin? ? admin_rsvps_path : root_path, alert: (user.admin? ? nil : "That account isn't an Overdrive admin."))
    end

    if user.rsvp_blocked?
      return redirect_to root_path(anchor: "rsvp"),
        alert: user.aged_out? ? "Overdrive is for teenagers 18 and under, so you can't RSVP. Sorry!" : "Your Hack Club account isn't eligible to RSVP."
    end

    result = RsvpForUser.call(user, source: "hca", cookie_rsvp: remembered_rsvp, attrs: { ref: session[:ref] })
    cookies.delete(:rsvp_id)
    redirect_to thanks_rsvp_path, notice: result.created? ? nil : "You're linked to Hack Club. You're all set!"
  end

  def failure
    redirect_to root_path(anchor: "rsvp"), alert: "Hack Club sign-in didn't work. Try again, or RSVP with your email."
  end

  def destroy
    reset_session
    redirect_to root_path
  end

  private

  def reset_session_keeping_ref
    ref = session[:ref]
    reset_session
    session[:ref] = ref if ref
  end
end
