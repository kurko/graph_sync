require "spec_helper"

describe GraphSync::NodesDiff do
  subject do
    described_class.new(
      node_a: node_a,
      node_b: node_b,
      rules: rules,
    )
  end

  describe "#to_update_on_b" do
    describe "primitive values" do
      let(:node_a) { double(daily_budget: budget_a) }
      let(:node_b) { double(budget_amount: budget_b) }

      let(:rules) do
        [
          {
            node_a_attr: :daily_budget,
            node_b_attr: :budget_amount,
            canonical_node: :node_a,
          },
        ]
      end

      context "when budgets differ" do
        let(:budget_a) { Amount.new(in_cents: 123) }
        let(:budget_b) { Amount.new(in_micro: "1240000") } # micro

        it "returns hash with values to update" do
          expect(subject.to_update_on_b).to eq({
            budget_amount: Amount.new(in_cents: 123),
          })
        end
      end

      context "when budgets are equal" do
        let(:budget_a) { 123 }
        let(:budget_b) { 123 } # micro

        it "returns hash with values to update" do
          expect(subject.to_update_on_b).to eq({})
        end
      end
    end

    describe "when objects have `id`" do
      let(:node_a) { double(id: :a_id, attr: true) }
      let(:node_b) { double(id: :b_id, attr: false) }
      let(:rules) do
        [
          {
            node_a_attr: :attr,
            node_b_attr: :attr,
            canonical_node: :node_a,
          },
        ]
      end

      let(:budget_a) { Amount.new(in_cents: 123) }
      let(:budget_b) { Amount.new(in_micro: "1240000") } # micro

      context "when node_a is canonical" do
        let(:canonical) { :node_a }

        it "returns hash with values to update incl. node_a's id" do
          expect(subject.to_update_on_b).to eq({
            id: :b_id,
            attr: true,
          })
        end
      end
    end

    describe "custom values" do
      context "node_a:enabled <-> node_b:paused" do
        let(:node_a) { double(state: "enabled") }
        let(:node_b) { double(status: "paused") }

        let(:rules) do
          [
            {
              node_a_attr: :state,
              node_b_attr: :status,
              canonical_node: :node_a,
            },
          ]
        end

        let(:expected) { {status: "enabled"} }
        it { expect(subject.to_update_on_b).to eq(expected) }
      end

      context "node_a:enabled <-> node_b:active, solved with diff_if" do
        let(:node_a) { double(state: "enabled") }
        let(:node_b) { double(status: "active") }

        let(:rules) do
          [
            {
              node_a_attr: :state,
              node_b_attr: :status,
              diff_if: ->(a, b) {
                state = RemoteAdService::StateDictionary.new(b.status).local_name
                state != a.state
              },
              canonical_node: :node_a,
            },
          ]
        end

        let(:expected) { {} }
        it { expect(subject.to_update_on_b).to eq(expected) }
      end
    end

    describe "custom proc" do
      let(:node_a) { double(state: "enabled") }
      let(:node_b) { double(status: "active") }

      context "when proc returns true" do
        let(:rules) do
          [
            {
              node_a_attr: :state,
              node_b_attr: :status,
              diff_if: ->(a, b) { true },
              canonical_node: :node_a,
            },
          ]
        end
        let(:expected) { {status: "enabled"} }

        it { expect(subject.to_update_on_b).to eq(expected) }
      end

      context "when proc returns false" do
        let(:rules) do
          [
            {
              node_a_attr: :state,
              node_b_attr: :status,
              diff_if: ->(a, b) { false },
              canonical_node: :node_a,
            },
          ]
        end
        let(:expected) { {} }
        it { expect(subject.to_update_on_b).to eq(expected) }
      end
    end
  end
end
