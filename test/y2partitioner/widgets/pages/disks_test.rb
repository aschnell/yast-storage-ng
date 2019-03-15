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
# find current contact information at www.suse.com

require_relative "../../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/pages"

describe Y2Partitioner::Widgets::Pages::Disks do
  before { devicegraph_stub(scenario) }
  let(:scenario) { "mixed_disks_btrfs.yml" }

  let(:device_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  subject { described_class.new(disks, pager) }

  let(:disks) { device_graph.disks }

  let(:pager) { double("OverviewTreePager") }

  include_examples "CWM::Page"

  describe "#contents" do
    let(:widgets) { Yast::CWM.widgets_in_contents([subject]) }
    let(:table) { widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::BlkDevicesTable) } }
    let(:disks_and_parts) do
      (device_graph.disks + device_graph.disks.map(&:partitions)).flatten.compact
    end

    it "shows a table with the disk devices and their partitions" do
      expect(table).to_not be_nil

      devices_name = disks_and_parts.map(&:name)
      items_name = table.items.map { |i| bidi_strip(i[1]) }

      expect(items_name.sort).to eq(devices_name.sort)
    end

    # This test is here to ensure we don't try to access the partitions within a
    # StrayBlkDevice or something similar
    context "when some of the devices to show are Xen virtual partitions" do
      let(:scenario) { "xen-disks-and-partitions.xml" }
      let(:disks) { device_graph.disks + device_graph.stray_blk_devices }

      it "shows a table with the disk devices, their partitions and the Xen virtual partitions" do
        devices = disks_and_parts + device_graph.stray_blk_devices
        devices_name = devices.map(&:name)
        items_name = table.items.map { |i| bidi_strip(i[1]) }

        expect(items_name.sort).to eq(devices_name.sort)
      end
    end
  end
end
