class ContactMessagesController < ApplicationController
  def new
    @contact_message = ContactMessage.new
  end

  def create
    # Honeypot — a real visitor never sees or fills params[:website] (see
    # the view). A bot that fills every field gets a fake success, with
    # nothing saved and no mail sent, and no signal that it was caught.
    if params[:website].present?
      redirect_to contact_path, notice: "Thanks for reaching out — our team will get back to you shortly."
      return
    end

    @contact_message = ContactMessage.new(contact_message_params)

    if @contact_message.save
      ContactMailer.acknowledgement(@contact_message).deliver_later
      ContactMailer.new_submission(@contact_message).deliver_later
      redirect_to contact_path, notice: "Thanks for reaching out — our team will get back to you shortly."
    else
      render :new, status: :unprocessable_content
    end
  end

  private

  def contact_message_params
    params.require(:contact_message).permit(:name, :email, :phone, :subject, :message)
  end
end
