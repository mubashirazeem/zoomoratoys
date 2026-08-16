# frozen_string_literal: true

require "rails_helper"

RSpec.describe ExchangeRates::RefreshJob, type: :job do
  def stub_http_response(response)
    http = instance_double(Net::HTTP)
    allow(Net::HTTP).to receive(:start).and_yield(http)
    allow(http).to receive(:get).and_return(response)
  end

  it "records the USD rate from a successful response" do
    body = { "rates" => { "USD" => 0.272294 } }.to_json
    stub_http_response(instance_double(Net::HTTPSuccess, is_a?: true, body: body))

    described_class.perform_now

    expect(ExchangeRate.first.usd_per_aed.to_f).to eq(0.272294)
  end

  it "does not record anything when the response isn't a success" do
    stub_http_response(instance_double(Net::HTTPServerError, is_a?: false, code: "500"))

    expect { described_class.perform_now }.not_to change(ExchangeRate, :count)
  end

  it "does not record anything when the response has no USD rate" do
    body = { "rates" => { "EUR" => 0.23 } }.to_json
    stub_http_response(instance_double(Net::HTTPSuccess, is_a?: true, body: body))

    expect { described_class.perform_now }.not_to change(ExchangeRate, :count)
  end

  it "never raises, even if the request itself fails" do
    allow(Net::HTTP).to receive(:start).and_raise(Net::OpenTimeout)

    expect { described_class.perform_now }.not_to raise_error
  end

  it "never raises on a malformed (non-JSON) response body" do
    stub_http_response(instance_double(Net::HTTPSuccess, is_a?: true, body: "not json at all"))

    expect { described_class.perform_now }.not_to raise_error
    expect(ExchangeRate.count).to eq(0)
  end

  it "rejects a zero rate instead of recording a corrupted price for every USD shopper" do
    body = { "rates" => { "USD" => 0 } }.to_json
    stub_http_response(instance_double(Net::HTTPSuccess, is_a?: true, body: body))

    expect { described_class.perform_now }.not_to change(ExchangeRate, :count)
  end

  it "rejects a negative rate" do
    body = { "rates" => { "USD" => -0.27 } }.to_json
    stub_http_response(instance_double(Net::HTTPSuccess, is_a?: true, body: body))

    expect { described_class.perform_now }.not_to change(ExchangeRate, :count)
  end

  it "rejects an inverted rate (AED-per-USD ~3.67 mistaken for USD-per-AED) rather than making every price look 13x too expensive" do
    body = { "rates" => { "USD" => 3.6725 } }.to_json
    stub_http_response(instance_double(Net::HTTPSuccess, is_a?: true, body: body))

    expect { described_class.perform_now }.not_to change(ExchangeRate, :count)
  end

  it "rejects a non-numeric rate" do
    body = { "rates" => { "USD" => "0.27" } }.to_json
    stub_http_response(instance_double(Net::HTTPSuccess, is_a?: true, body: body))

    expect { described_class.perform_now }.not_to change(ExchangeRate, :count)
  end

  it "leaves the previous good rate in place when a later fetch returns something implausible" do
    ExchangeRate.create!(usd_per_aed: 0.272294, fetched_at: 1.day.ago)
    body = { "rates" => { "USD" => 0 } }.to_json
    stub_http_response(instance_double(Net::HTTPSuccess, is_a?: true, body: body))

    described_class.perform_now

    expect(ExchangeRate.first.usd_per_aed.to_f).to eq(0.272294)
  end

  it "updates the existing rate rather than leaving a stale one when it runs again" do
    ExchangeRate.create!(usd_per_aed: 0.2, fetched_at: 1.day.ago)
    body = { "rates" => { "USD" => 0.275 } }.to_json
    stub_http_response(instance_double(Net::HTTPSuccess, is_a?: true, body: body))

    described_class.perform_now

    expect(ExchangeRate.count).to eq(1)
    expect(ExchangeRate.first.usd_per_aed.to_f).to eq(0.275)
  end
end
