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

require "yast"
require "cwm/table"
require "y2partitioner/icons"
require "y2partitioner/widgets/help"

module Y2Partitioner
  module Widgets
    # Abstract class to unify the definition of table widgets used to
    # represent collections of block devices.
    #
    # The subclasses must define the following methods:
    #
    #   * #columns returning an array of symbols
    #   * #devices returning a collection of {Y2Storage::BlkDevice}
    class BlkDevicesTable < CWM::Table
      include Help
      extend Yast::I18n

      textdomain "storage"

      # @see CWM::Table#header
      def header
        columns.map { |c| send("#{c}_title") }
      end

      # @see CWM::Table#items
      def items
        devices.map { |d| values_for(d) }
      end

      # Updates table content
      def refresh
        change_items(items)
      end

    protected

      # Returns true if given sid or device is available in table
      # @param device [Y2Storage::Device, Integer] sid or device object
      def valid_sid?(device)
        return false if device.nil?

        sid = device.respond_to?(:sid) ? device.sid : device.to_i

        devices.any? { |d| d.sid == sid }
      end

    private

      # TRANSLATORS: "F" stands for Format flag. Keep it short, ideally a single letter.
      FORMAT_FLAG = N_("F")

      # @see #helptext_for
      def columns_help
        columns.map { |c| helptext_for(c) }.join("\n")
      end

      def values_for(device)
        [row_id(device)] + columns.map { |c| send("#{c}_value", device) }
      end

      # LibYUI id to use for the row used to represent a device
      #
      # @param device [Y2Storage::Device, Integer] sid or device object
      def row_id(device)
        sid = device.respond_to?(:sid) ? device.sid : device.to_i
        "table:device:#{sid}"
      end

      def filesystem(device)
        return device if device.is?(:filesystem)
        return nil unless device.respond_to?(:filesystem)
        device.filesystem
      end

      # Column titles

      def device_title
        # TRANSLATORS: table header, Device is physical name of block device, e.g. "/dev/sda1"
        _("Device")
      end

      def size_title
        # TRANSLATORS: table header, size of block device e.g. "8.00 GiB"
        Right(_("Size"))
      end

      def format_title
        Center(_(FORMAT_FLAG))
      end

      def encrypted_title
        # TRANSLATORS: table header, flag if device is encrypted. Keep it short,
        # ideally three letters. Keep in sync with Enc used later for format marker.
        Center(_("Enc"))
      end

      def type_title
        # TRANSLATORS: table header, type of disk or partition. Can be longer. E.g. "Linux swap"
        _("Type")
      end

      def filesystem_type_title
        # TRANSLATORS: table header, file system type
        _("FS Type")
      end

      def filesystem_label_title
        # TRANSLATORS: table header, disk or partition label. Can be empty.
        _("Label")
      end

      def mount_point_title
        # TRANSLATORS: table header, where is device mounted. Can be empty. E.g. "/" or "/home"
        _("Mount Point")
      end

      def start_title
        # TRANSLATORS: table header, which sector is the first one for device. E.g. "0"
        Right(_("Start"))
      end

      def end_title
        # TRANSLATORS: table header, which sector is the the last for device. E.g. "126"
        Right(_("End"))
      end

      # Values

      def bidi_supported?
        return @bidi_supported unless @bidi_supported.nil?
        di = Yast::UI.GetDisplayInfo()
        @bidi_supported = (di ? di["TextMode"] : nil) == false
      end

      def left_to_right(s)
        # ncurses would get confused and truncates the text instead
        return s unless bidi_supported?

        # If we used a plain device.name
        # then it would display as dev/sda1/ in a RTL context.
        # Unicode BiDi Left-to-right embedding (LRE),
        # then Pop Directional Formatting (PDF)
        format("\u{202A}%s\u{202C}", s)
      end

      def device_value(device)
        left_to_right(device.name)
      end

      def size_value(device)
        # TODO: displaying properly the size of NFS devices may imply some
        # inspection and caching. For the time being let's print nothing for
        # such devices without a direct and straightforward #size method.
        return "" unless device.respond_to?(:size)
        device.size.to_human_string
      end

      def format_value(device)
        return "" unless device.respond_to?(:to_be_formatted?)
        already_formatted = !device.to_be_formatted?(DeviceGraphs.instance.system)
        already_formatted ? "" : _(FORMAT_FLAG)
      end

      def encrypted_value(device)
        return "" unless device.respond_to?(:encrypted?)
        return "" unless device.encrypted?

        if Yast::UI.GetDisplayInfo["HasIconSupport"]
          cell(icon(Icons::ENCRYPTED))
        else
          "E"
        end
      end

      def type_value(device)
        icon = type_icon(device)
        label = type_label(device)
        cell(icon, label)
      end

      def filesystem_type_value(device)
        fs = filesystem(device)
        return "" if fs.nil?

        type = fs.type
        type.nil? ? "" : type.to_human
      end

      def filesystem_label_value(device)
        fs = filesystem(device)
        # fs may be nil or a file system not supporting labels, like NFS
        return "" unless fs.respond_to?(:label)
        fs.label
      end

      def mount_point_value(device)
        fs = filesystem(device)
        return "" if fs.nil?

        res = fs.mount_path
        res += " *" if fs.mount_point && !fs.mount_point.active?

        res
      end

      def start_value(device)
        return "" unless device.respond_to?(:region)
        return "" if device.region.empty?
        device.region.start
      end

      def end_value(device)
        return "" unless device.respond_to?(:region)
        return "" if device.region.empty?
        device.region.end
      end

      DEVICE_ICONS = {
        bcache:    Icons::BCACHE,
        disk:      Icons::HD,
        dasd:      Icons::HD,
        multipath: Icons::MULTIPATH,
        nfs:       Icons::NFS,
        partition: Icons::HD_PART,
        raid:      Icons::RAID,
        lvm_vg:    Icons::LVM,
        lvm_lv:    Icons::LVM_LV
      }

      # Table icon for the device
      #
      # @see DEVICE_ICONS
      #
      # @param device [Y2Storage::BlkDevice]
      # @return [Yast::Term] icon
      def type_icon(device)
        return type_icon(device.plain_blk_device) if device.is?(:lvm_pv)

        type = DEVICE_ICONS.keys.find { |k| device.is?(k) }
        icon_name = type.nil? ? Icons::DEFAULT_DEVICE : DEVICE_ICONS[type]

        icon(icon_name)
      end

      DEVICE_LABELS = {
        bcache:        N_("Bcache"),
        disk:          N_("Disk"),
        dasd:          N_("Disk"),
        multipath:     N_("Multipath"),
        nfs:           N_("NFS"),
        bios_raid:     N_("BIOS RAID"),
        software_raid: N_("MD RAID"),
        lvm_pv:        N_("PV"),
        lvm_vg:        N_("LVM"),
        lvm_lv:        N_("LV"),
        stray:         N_("Xen"),
        thin_pool:     N_("Thin Pool"),
        thin:          N_("Thin LV")
      }

      # Label for the device type (e.g., LVM, MD RAID)
      #
      # @param device [Y2Storage::BlkDevice]
      # @return [String]
      def type_label(device)
        return default_type_label(device) unless device.is_a?(Y2Storage::BlkDevice)

        if device.is?(:partition)
          partition_type_label(device)
        elsif device.is?(:lvm_lv)
          lvm_lv_type_label(device)
        else
          blk_device_type_label(device)
        end
      end

      # Default type label for the device
      #
      # @see DEVICE_LABELS
      #
      # @param device [Y2Storage::BlkDevice]
      # @return [String]
      def default_type_label(device)
        type = DEVICE_LABELS.keys.find { |k| device.is?(k) }
        return "" if type.nil?

        _(DEVICE_LABELS[type])
      end

      # Type label when the device is a partition
      #
      # @param device [Y2Storage::Partition]
      # @return [String]
      def partition_type_label(device)
        device.id.to_human_string
      end

      # Type label when the device is a LVM logical volume
      #
      # @note Different label is shown depending on the logical volume type
      #   (i.e., normal, thin pool or thin volume).
      #
      # @param device [Y2Storage::LvmLv]
      # @return [String]
      def lvm_lv_type_label(device)
        return blk_device_type_label(device) if device.lv_type.is?(:normal)

        type = device.lv_type.to_sym
        _(DEVICE_LABELS[type]) || ""
      end

      # Type label when the device is not a partition
      #
      # @param device [Y2Storage::BlkDevice]
      # @return [String]
      def blk_device_type_label(device)
        data = [device.vendor, device.model].compact
        # bcache has as vendor Disk, but we want to write bcache as type here
        data = "" if device.is?(:bcache)
        data.empty? ? default_type_label(device) : data.join("-")
      end
    end
  end
end
