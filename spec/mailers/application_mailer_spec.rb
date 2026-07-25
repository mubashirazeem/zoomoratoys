require "rails_helper"

RSpec.describe ApplicationMailer do
  it "sends from the real Zoomora domain, not Rails' unconfigured placeholder" do
    expect(described_class.default[:from]).to eq("no-reply@zoomora.com")
  end
end
