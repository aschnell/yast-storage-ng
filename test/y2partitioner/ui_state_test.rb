#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2017-2019] SUSE LLC
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

require_relative "test_helper"
require "y2partitioner/ui_state"
require "y2partitioner/widgets/pages"

describe Y2Partitioner::UIState do
  subject(:ui_state) { described_class.instance }

  before { devicegraph_stub(scenario) }

  let(:scenario) { "complex-lvm-encrypt.yml" }

  let(:device) { Y2Storage::BlkDevice.find_by_name(fake_devicegraph, device_name) }

  let(:disks) { fake_devicegraph.disks }

  describe ".new" do
    it "cannot be used directly" do
      expect { described_class.new }.to raise_error(/private method/)
    end
  end

  describe ".instance" do
    it "returns the singleton object in subsequent calls" do
      initial = described_class.create_instance
      second = described_class.instance
      # Note using equal to ensure is actually the same object (same object_id)
      expect(second).to equal initial
      expect(described_class.instance).to equal initial
    end
  end

  describe ".create_instance" do
    it "returns a new singleton UIState object" do
      initial = described_class.instance
      result = described_class.create_instance
      expect(result).to be_a described_class
      expect(result).to_not equal initial
    end
  end

  describe "#find_tree_node" do
    let(:pager) { double("TreePager") }
    let(:system_page) { Y2Partitioner::Widgets::Pages::System.new("", pager) }
    let(:disks_page) { Y2Partitioner::Widgets::Pages::Disks.new(disks, pager) }
    let(:md_raids_page) { Y2Partitioner::Widgets::Pages::MdRaids.new(pager) }
    let(:lvm_page) { Y2Partitioner::Widgets::Pages::Lvm.new(pager) }
    let(:bcaches_page) { Y2Partitioner::Widgets::Pages::Bcaches.new([], pager) }
    let(:btrfs_page) { Y2Partitioner::Widgets::Pages::Btrfs.new(pager) }

    let(:pages) { [system_page, disks_page, md_raids_page, lvm_page, bcaches_page, btrfs_page] }

    context "if the user has still not visited any node" do
      before { described_class.create_instance }

      it "returns nil" do
        expect(ui_state.find_tree_node(pages)).to be_nil
      end
    end

    context "when the user has opened a partition page" do
      let(:device_name) { "/dev/sda1" }
      let(:another_disk) { Y2Storage::Disk.find_by_name(fake_devicegraph, "/dev/sdb") }

      let(:page) { Y2Partitioner::Widgets::Pages::Partition.new(device) }
      let(:another_disk_page) { Y2Partitioner::Widgets::Pages::Disk.new(another_disk, pager) }
      let(:disk_page) { Y2Partitioner::Widgets::Pages::Disk.new(device.disk, pager) }

      before { ui_state.go_to_tree_node(page) }

      context "if the partition is still there after redrawing" do
        before { pages.concat [page, another_disk_page, disk_page] }

        it "selects the partition page" do
          expect(ui_state.find_tree_node(pages)).to eq page
        end
      end

      context "if the partition is not longer there after redrawing" do
        before { pages.concat [another_disk_page, disk_page] }

        it "selects the corresponding disk page" do
          expect(ui_state.find_tree_node(pages)).to eq disk_page
        end
      end

      context "if the whole disk is not longer there after redrawing" do
        before { pages << another_disk_page }

        it "returns nil" do
          expect(ui_state.find_tree_node(pages)).to be_nil
        end
      end
    end

    context "when the user has opened a disk page" do
      let(:device_name) { "/dev/sdb" }
      let(:another_disk) { Y2Storage::Disk.find_by_name(fake_devicegraph, "/dev/sda") }

      let(:page) { Y2Partitioner::Widgets::Pages::Disk.new(device, pager) }
      let(:another_disk_page) { Y2Partitioner::Widgets::Pages::Disk.new(another_disk, pager) }

      before { ui_state.go_to_tree_node(page) }

      context "if the disk is still there after redrawing" do
        before { pages.concat [page, another_disk_page] }

        it "selects the correct disk page" do
          expect(ui_state.find_tree_node(pages)).to eq page
        end
      end

      context "if the disk is not longer there after redrawing" do
        before { pages << another_disk_page }

        it "returns nil" do
          expect(ui_state.find_tree_node(pages)).to be_nil
        end
      end
    end

    context "when the user has opened an MD RAID page" do
      let(:device_name) { "/dev/md0" }

      let(:page) { Y2Partitioner::Widgets::Pages::MdRaid.new(device, pager) }

      before do
        Y2Storage::Md.create(fake_devicegraph, "/dev/md0")
        ui_state.go_to_tree_node(page)
      end

      context "if the RAID is still there after redrawing" do
        before { pages << page }

        it "selects the RAID page" do
          expect(ui_state.find_tree_node(pages)).to eq page
        end
      end

      context "if the RAID is not longer there after redrawing" do
        it "selects the general MD RAIDs page" do
          expect(ui_state.find_tree_node(pages)).to eq md_raids_page
        end
      end
    end

    context "when the user has opened a LV page" do
      let(:device_name) { "/dev/vg0/lv1" }

      let(:page) { Y2Partitioner::Widgets::Pages::LvmLv.new(device) }
      let(:vg_page) { Y2Partitioner::Widgets::Pages::LvmVg.new(device.lvm_vg, pager) }

      before { ui_state.go_to_tree_node(page) }

      context "if the LV is still there after redrawing" do
        before { pages.concat [page, vg_page] }

        it "selects the LV page" do
          expect(ui_state.find_tree_node(pages)).to eq page
        end
      end

      context "if the LV is not longer there after redrawing" do
        before { pages << vg_page }

        it "selects the corresponding VG page" do
          expect(ui_state.find_tree_node(pages)).to eq vg_page
        end
      end

      context "if the whole VG is not longer there after redrawing" do
        it "returns nil" do
          expect(ui_state.find_tree_node(pages)).to be_nil
        end
      end
    end

    context "when the user has opened a VG page" do
      let(:device) { Y2Storage::LvmVg.find_by_vg_name(fake_devicegraph, "vg0") }
      let(:another_vg) { Y2Storage::LvmVg.find_by_vg_name(fake_devicegraph, "vg1") }

      let(:page) { Y2Partitioner::Widgets::Pages::LvmVg.new(device, pager) }
      let(:another_vg_page) { Y2Partitioner::Widgets::Pages::LvmVg.new(another_vg, pager) }

      before { ui_state.go_to_tree_node(page) }

      context "if the VG is still there after redrawing" do
        before { pages.concat [page, another_vg_page] }

        it "selects the correct VG page" do
          expect(ui_state.find_tree_node(pages)).to eq page
        end
      end

      context "if the VG is not longer there after redrawing" do
        before { pages << another_vg_page }

        it "selects the general LVM page" do
          expect(ui_state.find_tree_node(pages)).to eq lvm_page
        end
      end
    end

    context "when the user has opened a bcache page" do
      let(:scenario) { "bcache1.xml" }
      let(:device) { fake_devicegraph.find_by_name("/dev/bcache0") }
      let(:another_bcache) { fake_devicegraph.find_by_name("/dev/bcache1") }

      let(:page) { Y2Partitioner::Widgets::Pages::Bcache.new(device, pager) }
      let(:another_bcache_page) { Y2Partitioner::Widgets::Pages::Bcache.new(another_bcache, pager) }

      before { ui_state.go_to_tree_node(page) }

      context "if the bcache is still there after redrawing" do
        before { pages.concat [page, another_bcache_page] }

        it "selects the correct bcache page" do
          expect(ui_state.find_tree_node(pages)).to eq page
        end
      end

      context "if the bcache is not longer there after redrawing" do
        before { pages << another_bcache_page }

        it "selects the general bcache page" do
          expect(ui_state.find_tree_node(pages)).to eq bcaches_page
        end
      end
    end
  end

  describe "#find_tab" do
    let(:pager) { double("TreePager") }
    let(:vg) { Y2Storage::LvmVg.find_by_vg_name(fake_devicegraph, "vg0") }

    let(:vg_tab) { Y2Partitioner::Widgets::Pages::LvmVgTab.new(vg) }
    let(:lvs_tab) { Y2Partitioner::Widgets::Pages::LvmLvTab.new(vg, pager) }
    let(:pvs_tab) { Y2Partitioner::Widgets::Pages::LvmPvTab.new(vg, pager) }

    let(:tabs) { [vg_tab, lvs_tab, pvs_tab] }

    context "if the user has still not clicked in any tab" do
      before { described_class.create_instance }

      it "returns nil" do
        expect(ui_state.find_tab(tabs)).to be_nil
      end
    end

    context "if the user has switched to a tab in the current tree node" do
      before { ui_state.switch_to_tab(lvs_tab) }

      it "selects the corresponding page" do
        expect(ui_state.find_tab(tabs)).to eq lvs_tab
      end
    end

    context "if the switched to a tab but then moved to a different tree node" do
      let(:another_node) { double("Page", label: "A section") }

      before do
        ui_state.switch_to_tab(lvs_tab)
        ui_state.go_to_tree_node(another_node)
      end

      it "returns nil even if there is another tab with the same label" do
        expect(ui_state.find_tab(tabs)).to be_nil
      end
    end
  end

  describe "#row_sid" do
    let(:device_name) { "/dev/sda2" }

    context "if the user has still not selected any row" do
      before { described_class.create_instance }

      it "returns nil" do
        expect(ui_state.row_sid).to be_nil
      end
    end

    context "if the user had selected a row in the current node and tab" do
      context "selecting the row by device" do
        before { ui_state.select_row(device) }

        it "returns the sid of the device" do
          expect(ui_state.row_sid).to eq device.sid
        end
      end

      context "selecting the row by sid" do
        before { ui_state.select_row(device.sid) }

        it "returns the sid of the device" do
          expect(ui_state.row_sid).to eq device.sid
        end
      end
    end

    context "if the user had selected a row but then moved to a different tab" do
      let(:another_tab) { double("Tab", label: "A tab") }

      before do
        ui_state.select_row(device)
        ui_state.switch_to_tab(another_tab)
      end

      it "returns nil" do
        expect(ui_state.row_sid).to be_nil
      end
    end

    context "if the user had selected a row but then moved to a different tree node" do
      let(:another_node) { double("Page", label: "Somewhere") }

      before do
        ui_state.select_row(device)
        ui_state.go_to_tree_node(another_node)
      end

      it "returns nil" do
        expect(ui_state.row_sid).to be_nil
      end
    end
  end

  describe "#open_items_ids" do
    context "if the open items has not been saved" do
      before { described_class.create_instance }

      it "returns nil" do
        expect(ui_state.open_items_ids).to be_nil
      end
    end

    context "after calling #save_open_items" do
      let(:pager) { double("TreePager") }

      before do
        # The first call returns [:first, :third] and the second returns [:second]
        allow(pager).to receive(:open_items_ids)
          .and_return([:first, :third], [:second])

        ui_state.overview_tree_pager = pager
        ui_state.save_open_items
      end

      it "returns the items that were expanded when #save_open_items was called" do
        expect(ui_state.open_items_ids).to eq [:first, :third]
      end
    end
  end
end
