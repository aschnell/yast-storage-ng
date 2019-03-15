#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2017] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require_relative "../../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/pages/lvm_vg"

describe Y2Partitioner::Widgets::Pages::LvmVg do
  before { devicegraph_stub("lvm-two-vgs.yml") }

  subject { described_class.new(lvm_vg, pager) }

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:lvm_vg) { Y2Storage::LvmVg.find_by_vg_name(current_graph, "vg0") }

  let(:pager) { double("Pager") }

  include_examples "CWM::Page"

  describe "#contents" do
    let(:widgets) { Yast::CWM.widgets_in_contents([subject]) }

    it "shows a vg tab" do
      expect(Y2Partitioner::Widgets::Pages::LvmVgTab).to receive(:new)
      subject.contents
    end

    it "shows a lvs tab" do
      expect(Y2Partitioner::Widgets::Pages::LvmLvTab).to receive(:new)
      subject.contents
    end

    it "shows a pvs tab" do
      expect(Y2Partitioner::Widgets::Pages::LvmPvTab).to receive(:new)
      subject.contents
    end
  end

  describe Y2Partitioner::Widgets::Pages::LvmVgTab do
    subject { described_class.new(lvm_vg) }

    include_examples "CWM::Tab"

    let(:widgets) { Yast::CWM.widgets_in_contents([subject]) }

    it "shows the description of the vg" do
      description = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::LvmVgDescription) }
      expect(description).to_not be_nil
    end
  end

  describe Y2Partitioner::Widgets::Pages::LvmLvTab do
    subject { described_class.new(lvm_vg, pager) }

    include_examples "CWM::Tab"

    describe "#contents" do
      let(:widgets) { Yast::CWM.widgets_in_contents([subject]) }

      let(:table) { widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::LvmDevicesTable) } }

      let(:items) { table.items.map { |i| bidi_strip(i[1]) } }

      before do
        create_thin_provisioning(lvm_vg)
      end

      it "shows a table with the lvs of a vg (including thin volumes)" do
        expect(table).to_not be_nil

        expect(items).to contain_exactly(
          "/dev/vg0/lv1",
          "/dev/vg0/lv2",
          "/dev/vg0/pool1",
          "/dev/vg0/thin1",
          "/dev/vg0/thin2",
          "/dev/vg0/pool2",
          "/dev/vg0/thin3"
        )
      end

      it "shows a button to create a new lv" do
        button = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::LvmLvAddButton) }
        expect(button).to_not be_nil
      end
    end
  end

  describe Y2Partitioner::Widgets::Pages::LvmPvTab do
    subject { described_class.new(lvm_vg, pager) }

    include_examples "CWM::Tab"
  end
end
