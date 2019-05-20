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

require "yast"
require "cwm/widget"
require "yast2/popup"
require "y2partitioner/widgets/blk_devices_table"
require "y2partitioner/device_graphs"

module Y2Partitioner
  module Widgets
    # Widget to select a fstab file used to import mount points
    #
    # It shows information about the fstab entries and allows to switch between
    # the list of ftabs files detected in the whole system.
    class FstabSelector < CWM::CustomWidget
      # Constructor
      #
      # @param controller [Actions::Controllers::Fstabs]
      def initialize(controller)
        textdomain "storage"

        self.handle_all_events = true

        @controller = controller
      end

      # Selects the first fstab by default
      def init
        controller.selected_fstab = controller.fstabs.first
        refresh
      end

      def contents
        @contents ||= VBox(
          fstab_area,
          HBox(*buttons)
        )
      end

      # Checks whether the mount points of the selected fstab can be imported
      #
      # It shows a popup with the errors detected in the selected fstab.
      #
      # @see Actions::Controllers::Fstabs#selected_fstab_errors
      #
      # @return [Boolean]
      def validate
        errors = controller.selected_fstab_errors
        return true if errors.empty?

        message = errors.append(_("Do you want to continue?")).join("\n\n")

        Yast2::Popup.show(message, headline: :warning, buttons: :yes_no) == :yes
      end

      def handle(event)
        id = event["ID"]
        return nil unless id

        case id.to_sym
        when :show_prev
          controller.select_prev_fstab
          refresh
        when :show_next
          controller.select_next_fstab
          refresh
        when :help
          # FIXME: The help handle does not work without a wizard
          Yast::Wizard.ShowHelp(help)
        end

        nil
      end

      # @return [String]
      def help
        _("<p>YaST has scanned your hard disks and found one or several existing Linux " \
          "systems with mount points. The old mount points are shown in the table.</p>")
      end

    private

      # @return [Actions::Controllers::Fstabs]
      attr_reader :controller

      # Area where the data about a fstab file is shown
      #
      # This area is refreshed when switching between fstab files.
      #
      # @return [FstabArea]
      def fstab_area
        @fstab_area ||= FstabArea.new(controller)
      end

      # Buttons to switch between fstab files
      #
      # @return [List<Yast::UI::Term>]
      def buttons
        [show_prev_button, show_next_button]
      end

      # Button to go to the previous fstab file
      #
      # @return [Yast::UI::Term]
      def show_prev_button
        PushButton(Id(:show_prev), _("Show &Previous"))
      end

      # Button to go to the next fstab file
      #
      # @return [Yast::UI::Term]
      def show_next_button
        PushButton(Id(:show_next), _("Show &Next"))
      end

      # Updates content
      def refresh
        fstab_area.refresh
        refresh_buttons
      end

      # Updates status of buttons to swicth between fstab files
      def refresh_buttons
        refresh_show_prev_button
        refresh_show_next_button
      end

      # Disables the "show_prev" button if the selected fstab file is the first one
      def refresh_show_prev_button
        enabled = !controller.selected_first_fstab?
        Yast::UI.ChangeWidget(Id(:show_prev), :Enabled, enabled)
      end

      # Disables the "show_next" button if the selected fstab file is the last one
      def refresh_show_next_button
        enabled = !controller.selected_last_fstab?
        Yast::UI.ChangeWidget(Id(:show_next), :Enabled, enabled)
      end

      # Widget that contains fstab file info
      class FstabArea < CWM::ReplacePoint
        # Constructor
        #
        # @param controller [Actions::Controllers::Fstabs]
        def initialize(controller)
          @controller = controller

          super(id: "fstab_area", widget: fstab_content)
        end

        # Refreshes the widget with the content of the current selected fstab file
        def refresh
          replace(fstab_content)
        end

      private

        # @return [Actions::Controllers::Fstabs]
        attr_reader :controller

        # Content of the selected fstab file
        #
        # @return [FstabContent]
        def fstab_content
          FstabContent.new(controller.selected_fstab)
        end
      end

      # Widget with the content of a fstab file
      class FstabContent < CWM::CustomWidget
        # Constructor
        #
        # @param fstab [Y2Storage::Fstab]
        def initialize(fstab)
          textdomain "storage"
          @fstab = fstab
        end

        def contents
          @contents ||= VBox(
            Left(title),
            table
          )
        end

      private

        # @return [Y2Storage::Fstab]
        attr_reader :fstab

        # Label to show where the fstab file is located
        #
        # @return [Yast::UI::Term]
        def title
          Label(
            format(
              # TRANSLATORS: %{device_name} is replaced by the name of a device (e.g., /dev/sda1)
              _("/etc/fstab found on %{device_name} contains:"),
              device_name: fstab.device.name
            )
          )
        end

        # Table with each entry of a fstab file
        #
        # @return [FstabTable]
        def table
          FstabTable.new(fstab)
        end
      end

      # Table to show the content of a fstab file
      #
      # It contains a row for each fstab entry (excluding BTRFS subvolumes)
      class FstabTable < Widgets::BlkDevicesTable
        # Constructor
        #
        # @param fstab [Y2Storage::Fstab]
        def initialize(fstab)
          textdomain "storage"
          @fstab = fstab
        end

      private

        # @return [Y2Storage::Fstab]
        attr_reader :fstab

        def columns
          [:device, :size, :type, :filesystem_type, :filesystem_label, :mount_point]
        end

        # For each row, the device is a fstab entry
        #
        # BTRFS subvolume entries are not taken into account
        # (see {Y2Storage::Fstab#filesystem_entries}).
        #
        # @return [Array<Y2Storage::SimpleEtcFstabEntry>]
        def devices
          fstab.filesystem_entries
        end

        # @return [Y2Storage::Devicegraph]
        def system_graph
          DeviceGraphs.instance.system
        end

        # This method is redefined to use #object_id instead of #sid
        #
        # {Widgets::BlkDevicesTable} expects to have a {Y2Storage::BlkDevice} for each row,
        # but in this case it has a {Y2Storage::SimpleEtcFstabEntry}, which does not respond
        # to #sid method.
        def row_id(entry)
          "table:device:#{entry.object_id}"
        end

        # Value for the device column
        #
        # It shows the value of the fstab entry when the device is not found in the system.
        #
        # @param entry [Y2Storage::SimpleEtcFstabEntry]
        def device_value(entry)
          device = entry.device(system_graph)
          device ? super(device) : entry.fstab_device
        end

        # Value for the size column
        #
        # It shows an empty string when the device is not found in the system.
        #
        # @param entry [Y2Storage::SimpleEtcFstabEntry]
        def size_value(entry)
          device = entry.device(system_graph)
          device ? super(device) : ""
        end

        # Value for the device type column
        #
        # It shows an empty string when the device is not found in the system.
        #
        # @param entry [Y2Storage::SimpleEtcFstabEntry]
        def type_value(entry)
          device = entry.device(system_graph)
          device ? super(device) : ""
        end

        # Value for the filesystem type column
        #
        # @param entry [Y2Storage::SimpleEtcFstabEntry]
        def filesystem_type_value(entry)
          entry.fs_type.to_human
        end

        # Value for the filesystem label column
        #
        # It shows an empty string when the device is not found in the system.
        #
        # @param entry [Y2Storage::SimpleEtcFstabEntry]
        def filesystem_label_value(entry)
          device = entry.device(system_graph)
          device ? super(device) : ""
        end

        # Value for the mount point column
        #
        # It shows the mount point indicated in the fstab entry.
        #
        # @param entry [Y2Storage::SimpleEtcFstabEntry]
        def mount_point_value(entry)
          entry.mount_point
        end
      end
    end
  end
end
