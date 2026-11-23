class PagesController < ApplicationController
  def home
    session[:ref] = params[:ref] if params[:ref].to_s.match?(/\A[\w-]{1,64}\z/)
    @rsvp = Rsvp.new(ref: session[:ref])
    @stats = Rsvp.stats
    @my_rsvp = current_user&.rsvp || remembered_rsvp
  end
end
