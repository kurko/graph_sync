RSpec.describe GraphSync::NodeSetIntersection do
  let(:existing_resource) do
    [
      to_delete,
      double("2", remote_id: 2, status: "removed"),
      double("3", remote_id: 3, status: "PAUSED"),
      double("4", remote_id: 4, status: "enabled"),
      to_remain_untouched,
      double("7", remote_id: 7, status: "removed"),
      double("8", remote_id: 8, status: "disabled"),
      double("9", remote_id: 11, status: "DISABLED"),
      to_disable,
    ]
  end

  let(:new_resource) do
    [
      to_enable1,
      to_enable2,
      double("3", remote_id: 3, status: "paused"), # doesn't change
      to_remain_untouched, # doesn't change
      to_pause,
      to_create1,
      to_create2,
      to_ignore,
      with_id_but_not_remote,
    ]
  end

  let(:to_create1) { double("nil-enabled", remote_id: nil, status: "enabled") }
  let(:to_create2) { double("10", remote_id: 10, status: "enabled") }
  let(:to_ignore)  { double("nil-paused", remote_id: nil, status: "paused") }
  let(:to_pause)   { double("4", remote_id: 4, status: "paused") }
  let(:to_enable1) { double("2", remote_id: 2, status: "enabled") }
  let(:to_enable2) { double("8", remote_id: 8, status: "enabled") }
  let(:to_disable) { double("9", remote_id: 9, status: "enabled") }
  let(:to_delete)  { double("1", remote_id: 1, status: "enabled") }
  let(:to_remain_untouched) { double("6", remote_id: 6, status: "enabled") }
  let(:with_id_but_not_remote) { double("100", remote_id: 100, status: "enabled") }

  subject do
    described_class.new(
      set_a: new_resource,
      set_b: existing_resource,
      id_attr: :remote_id,
    )
  end

  describe "#to_create_in_b" do
    it "returns only resources that need to be created" do
      expect(subject.to_create_in_b).to eq [to_create1, to_create2, with_id_but_not_remote]
    end
  end

  describe "#to_pause" do
    it "returns only resources that need to be paused" do
      expect(subject.to_pause).to eq [to_pause]
    end
  end

  describe "#to_enable" do
    it "returns only resources that need to be enabled" do
      expect(subject.to_enable).to eq [to_enable1, to_enable2]
    end
  end

  describe "#to_delete" do
    it "returns only resources that need to be deleted" do
      expect(subject.to_delete).to eq [to_delete, to_disable]
    end
  end

  describe "#to_disable" do
    it "returns only resources that need to be disabled" do
      expect(subject.to_disable).to eq [to_delete, to_disable]
    end
  end

  describe "#remain_enabled" do
    it "returns only resources that will be created or enabled" do
      expect(subject.remain_enabled).to match_array [
        to_create1,
        to_create2,
        with_id_but_not_remote,
        to_enable1,
        to_enable2,
        to_remain_untouched,
      ]
    end
  end
end
