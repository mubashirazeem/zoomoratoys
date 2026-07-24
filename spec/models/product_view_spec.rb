require "rails_helper"

RSpec.describe ProductView, type: :model do
  it { is_expected.to belong_to(:product) }
  it { is_expected.to validate_presence_of(:viewer_token) }

  describe ".record!" do
    it "creates a view for a new viewer" do
      product = create(:product)

      expect { described_class.record!(product: product, viewer_token: "abc") }
        .to change(described_class, :count).by(1)
    end

    it "does not create a second row for the same viewer within the current window" do
      product = create(:product)
      described_class.record!(product: product, viewer_token: "abc")

      expect { described_class.record!(product: product, viewer_token: "abc") }
        .not_to change(described_class, :count)
    end

    it "refreshes the existing row instead of creating a new one once the window has passed" do
      product = create(:product)
      view = described_class.create!(product: product, viewer_token: "abc")
      view.update_column(:updated_at, 1.hour.ago)

      expect { described_class.record!(product: product, viewer_token: "abc") }
        .not_to change(described_class, :count)
      expect(view.reload.updated_at).to be_within(2.seconds).of(Time.current)
    end

    it "does not raise if the row was already created (e.g. by a concurrent request)" do
      product = create(:product)
      described_class.create!(product: product, viewer_token: "abc")

      expect { described_class.record!(product: product, viewer_token: "abc") }.not_to raise_error
    end
  end

  describe ".current_count_for" do
    it "counts distinct viewers within the current window" do
      product = create(:product)
      described_class.create!(product: product, viewer_token: "a")
      described_class.create!(product: product, viewer_token: "b")
      outside_window = described_class.create!(product: product, viewer_token: "c")
      outside_window.update_column(:updated_at, 1.hour.ago)

      expect(described_class.current_count_for(product)).to eq(2)
    end

    it "does not count views of a different product" do
      product = create(:product)
      other_product = create(:product)
      described_class.create!(product: other_product, viewer_token: "a")

      expect(described_class.current_count_for(product)).to eq(0)
    end
  end
end
