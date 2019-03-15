require_relative "../../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/pages"

describe Y2Partitioner::Widgets::Pages::MdRaids do
  before { devicegraph_stub(scenario) }

  subject { described_class.new(pager) }

  let(:pager) { double("OverviewTreePager") }

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:scenario) { "md_raid" }

  include_examples "CWM::Page"

  describe "#contents" do
    let(:scenario) { "nested_md_raids" }

    let(:widgets) { Yast::CWM.widgets_in_contents([subject]) }

    let(:table) { widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::BlkDevicesTable) } }
    let(:buttons_set) { widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::DeviceButtonsSet) } }

    let(:items) { table.items.map { |i| bidi_strip(i[1]) } }

    it "shows a button to add a raid" do
      button = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::MdAddButton) }
      expect(button).to_not be_nil
    end

    it "shows a set of buttons to manage the selected device" do
      expect(buttons_set).to_not be_nil
    end

    it "shows a table with the RAIDs and their partitions" do
      expect(table).to_not be_nil

      raids = current_graph.software_raids
      parts = raids.map(&:partitions).flatten.compact
      devices_name = (raids + parts).map(&:name)
      items_name = table.items.map { |i| bidi_strip(i[1]) }

      expect(items_name.sort).to eq(devices_name.sort)
    end

    it "associates the table and the set of buttons" do
      # Inspecting the value of #buttons_set may not be fully correct but is the
      # most straightforward and clear way of implementing this check
      expect(table.send(:buttons_set)).to eq buttons_set
    end

    context "when there are Software RAIDs" do
      let(:scenario) { "md_raid" }

      before do
        Y2Storage::Md.create(current_graph, "/dev/md1")
      end

      it "contains all Software RAIDs" do
        expect(items).to include(
          "/dev/md/md0",
          "/dev/md1"
        )
      end
    end

    context "when there are partitioned software RAIDs" do
      let(:scenario) { "nested_md_raids" }

      it "contains all software RAIDs and its partitions" do
        expect(items).to include("/dev/md0", "/dev/md0p1", "/dev/md0p2", "/dev/md1", "/dev/md2")
      end
    end

    context "when there is no Software RAID" do
      let(:scenario) { "md-imsm1-devicegraph.xml" }

      it "does not contain any device" do
        expect(items).to be_empty
      end
    end
  end
end
