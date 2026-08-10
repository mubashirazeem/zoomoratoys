class ApplicationMailer < ActionMailer::Base
  default from: "Zoomora Toys <sales@zoomora.com>"
  layout "mailer"

  # Mailer views don't get ApplicationHelper for free the way controller
  # views do — format_aed (the one currency formatter in the app) needs
  # this to be usable from any mailer template.
  helper :application

  before_action :attach_logo

  private

  # Inline (cid:) attachment, not a public asset URL — logo must render in
  # clients that block remote images by default (most webmail providers do,
  # for any first-open of an email from a new sender).
  def attach_logo
    attachments.inline["logo.png"] = File.read(Rails.root.join("app/assets/images/logo-transparent.png"))
  end
end
