class ContactMessagesController < ApplicationController
  def new
    @contact_message = ContactMessage.new
  end

  def create
    @contact_message = ContactMessage.new(contact_message_params)

    if @contact_message.save
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
