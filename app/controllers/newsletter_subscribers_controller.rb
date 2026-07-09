class NewsletterSubscribersController < ApplicationController
  def create
    @subscriber = NewsletterSubscriber.find_or_initialize_by(email: newsletter_params[:email])

    if @subscriber.persisted?
      redirect_back fallback_location: root_path, notice: "You're already on the list — thanks for being with us."
    elsif @subscriber.save
      redirect_back fallback_location: root_path, notice: "Thanks for subscribing! Watch your inbox for Zoomora Toys updates."
    else
      redirect_back fallback_location: root_path, alert: @subscriber.errors.full_messages.to_sentence
    end
  end

  private

  def newsletter_params
    params.require(:newsletter_subscriber).permit(:email)
  end
end
