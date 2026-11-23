class ApplicationController < ActionController::Base
  # No allow_browser gate: an RSVP page should never turn a teen away for an old school laptop.

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_user

  private

  def current_user
    return @current_user if defined?(@current_user)
    @current_user = session[:user_id] && User.find_by(id: session[:user_id])
  end

  # Signed cookie remembering an email RSVP made in this browser, so a later
  # Hack Club sign-in can link it even if the emails differ.
  def remember_email_rsvp(rsvp)
    cookies.signed[:rsvp_id] = { value: rsvp.id, expires: 1.year, httponly: true, same_site: :lax }
  end

  def remembered_rsvp
    (id = cookies.signed[:rsvp_id]) && Rsvp.find_by(id: id)
  end
end
