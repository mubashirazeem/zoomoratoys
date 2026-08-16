# frozen_string_literal: true

require "rails_helper"

RSpec.describe ExchangeRate, type: :model do
  describe ".current_usd_per_aed" do
    it "returns the real AED/USD peg and enqueues a refresh when no rate has ever been fetched" do
      expect {
        rate = described_class.current_usd_per_aed
        expect(rate).to eq(described_class::FALLBACK_USD_PER_AED)
      }.to have_enqueued_job(ExchangeRates::RefreshJob)
    end

    it "returns the stored rate without enqueuing a refresh when it's still fresh" do
      described_class.create!(usd_per_aed: 0.3, fetched_at: 1.hour.ago)

      expect {
        rate = described_class.current_usd_per_aed
        expect(rate).to eq(0.3)
      }.not_to have_enqueued_job(ExchangeRates::RefreshJob)
    end

    it "still returns the stale rate instantly, but enqueues a refresh for next time" do
      described_class.create!(usd_per_aed: 0.3, fetched_at: 13.hours.ago)

      expect {
        rate = described_class.current_usd_per_aed
        expect(rate).to eq(0.3)
      }.to have_enqueued_job(ExchangeRates::RefreshJob)
    end

    it "does not refresh a rate that's just barely within the freshness window" do
      described_class.create!(usd_per_aed: 0.3, fetched_at: (ExchangeRate::STALE_AFTER - 1.minute).ago)

      expect { described_class.current_usd_per_aed }.not_to have_enqueued_job(ExchangeRates::RefreshJob)
    end

    it "refreshes a rate that's just barely past the freshness window" do
      described_class.create!(usd_per_aed: 0.3, fetched_at: (ExchangeRate::STALE_AFTER + 1.minute).ago)

      expect { described_class.current_usd_per_aed }.to have_enqueued_job(ExchangeRates::RefreshJob)
    end

    it "reads instantly without ever making a network call itself — this is the whole point of stale-while-revalidate" do
      expect(Net::HTTP).not_to receive(:start)

      described_class.create!(usd_per_aed: 0.3, fetched_at: 1.year.ago)
      described_class.current_usd_per_aed
    end
  end

  describe ".record!" do
    it "creates the singleton row on the first call" do
      expect { described_class.record!(usd_per_aed: 0.27) }.to change(described_class, :count).by(1)

      expect(described_class.first.usd_per_aed.to_f).to eq(0.27)
    end

    it "updates the existing row instead of creating a second one" do
      described_class.create!(usd_per_aed: 0.2, fetched_at: 1.day.ago)

      expect { described_class.record!(usd_per_aed: 0.28) }.not_to change(described_class, :count)

      expect(described_class.first.usd_per_aed.to_f).to eq(0.28)
    end

    it "recovers instead of raising when the singleton row already exists at the moment of insert — the exact race two concurrent RefreshJob runs can hit on a fresh install (reproduced for real during manual testing: 5 rows landed in one dev DB from a single browsing session before this fix)" do
      described_class.create!(usd_per_aed: 0.2, fetched_at: Time.current)
      allow(described_class).to receive(:create!).and_raise(ActiveRecord::RecordNotUnique, "duplicate key")

      expect { described_class.record!(usd_per_aed: 0.28) }.not_to raise_error
      expect(described_class.count).to eq(1)
    end
  end

  describe "database-level singleton enforcement" do
    it "the unique index on singleton_guard — not just app logic — is what actually makes a second row impossible" do
      described_class.create!(usd_per_aed: 0.2, fetched_at: Time.current, singleton_guard: 1)

      expect {
        described_class.create!(usd_per_aed: 0.3, fetched_at: Time.current, singleton_guard: 1)
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
