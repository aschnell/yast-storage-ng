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

describe Y2Partitioner::Widgets::Pages::Btrfs do
  before do
    devicegraph_stub("mixed_disks_btrfs.yml")
  end

  let(:device_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:btrfs_filesystems) { device_graph.filesystems.select { |f| f.is?(:btrfs) } }

  let(:btrfs_devices) { btrfs_filesystems.map(&:blk_devices).flatten }

  subject { described_class.new(pager) }

  let(:pager) { double("OverviewTreePager") }

  include_examples "CWM::Page"

  describe "#contents" do
    let(:widgets) { Yast::CWM.widgets_in_contents([subject]) }

    it "shows a table with the devices formatted as btrfs" do
      table = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::BlkDevicesTable) }

      expect(table).to_not be_nil
      expect(table.items.size).to eq(5)

      devices_name = btrfs_devices.map(&:name)
      items_name = table.items.map { |i| bidi_strip(i[1]) }

      expect(items_name.sort).to eq(devices_name.sort)
    end

    it "shows an edit btrfs button" do
      button = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::BtrfsEditButton) }
      expect(button).to_not be_nil
    end
  end
end
