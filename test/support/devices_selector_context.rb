#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
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

RSpec.shared_context "devices selector" do
  def dev(name)
    Y2Storage::BlkDevice.find_by_name(current_graph, name)
  end

  def column_match?(column, regexp)
    if column.respond_to?(:match?)
      bidi_strip(column).match?(regexp)
    else
      false
    end
  end

  def row_match?(row, regexp)
    row.any? { |column| column_match?(column, regexp) }
  end

  def rows_match?(rows, *args)
    args.all? do |arg|
      rows.any? { |row| row_match?(row, arg) }
    end
  end

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:unselected_table) do
    widget.contents.nested_find { |i| i.is_a?(CWM::Table) && i.widget_id == "unselected" }
  end

  let(:selected_table) do
    widget.contents.nested_find { |i| i.is_a?(CWM::Table) && i.widget_id == "selected" }
  end

  before do
    # Ensure Yast::UI.Glyph and Yast::UI.GetDisplayInfo return something,
    # which is currently not guaranteed with the dummy UI used in the tests
    # (no ncurses or Qt).
    allow(Yast::UI).to receive(:Glyph).and_return ""
    allow(Yast::UI).to receive(:GetDisplayInfo).and_return("HasIconSupport" => false)
  end
end
