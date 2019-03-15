#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2018-2019] SUSE LLC
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

describe Y2Partitioner::Widgets::Pages::Bcaches do
  before { devicegraph_stub(scenario) }

  let(:architecture) { :x86_64 } # bcache is only supported on x86_64

  let(:scenario) { "bcache1.xml" }

  let(:device_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  subject { described_class.new(bcaches, pager) }

  let(:bcaches) { device_graph.bcaches }

  let(:pager) { double("OverviewTreePager") }

  include_examples "CWM::Page"

  describe "#contents" do
    let(:widgets) { Yast::CWM.widgets_in_contents([subject]) }

    it "shows a bcache devices tab" do
      expect(Y2Partitioner::Widgets::Pages::BcachesTab).to receive(:new)
      subject.contents
    end

    it "shows a caching set devices tab" do
      expect(Y2Partitioner::Widgets::Pages::BcacheCsetsTab).to receive(:new)
      subject.contents
    end
  end

  describe Y2Partitioner::Widgets::Pages::BcachesTab do
    subject { described_class.new(bcaches, pager) }

    include_examples "CWM::Tab"

    describe "#contents" do
      let(:widgets) { Yast::CWM.widgets_in_contents([subject]) }

      it "shows a table with the bcache devices and their partitions" do
        table = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::BlkDevicesTable) }

        expect(table).to_not be_nil

        devices = table.items.map { |i| bidi_strip(i[1]) }

        expect(devices).to contain_exactly("/dev/bcache0", "/dev/bcache1", "/dev/bcache2",
          "/dev/bcache0p1", "/dev/bcache2p1")
      end
    end
  end

  describe Y2Partitioner::Widgets::Pages::BcacheCsetsTab do
    subject { described_class.new(pager) }

    include_examples "CWM::Tab"

    describe "#contents" do
      before do
        vda1 = device_graph.find_by_name("/dev/vda1")
        vda1.create_bcache_cset
      end

      let(:widgets) { Yast::CWM.widgets_in_contents([subject]) }

      it "shows a table with the caching set devices" do
        table = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::BlkDevicesTable) }

        expect(table).to_not be_nil

        devices = table.items.map { |i| i[1] }

        expect(devices).to contain_exactly("/dev/vdb", "/dev/vda1")
      end
    end
  end
end
