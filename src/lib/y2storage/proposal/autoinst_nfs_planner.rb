# encoding: utf-8

# Copyright (c) [2019] SUSE LLC
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

require "y2storage/proposal/autoinst_drive_planner"

module Y2Storage
  module Proposal
    # This class converts an AutoYaST specification into a Planned::Nfs in order
    # to set up a NFS filesystem.
    class AutoinstNfsPlanner < AutoinstDrivePlanner
      # Returns an array of planned NFS filesystems according to an AutoYaST specification
      #
      # @param drive [AutoinstProfile::DriveSection] drive section describing NFS filesystems
      # @return [Array<Planned::Nfs>] Planned NFS filesystems
      def planned_devices(drive)
        # TODO: planned device with new format

        planned_devices_old_format(drive)
      end

    private

      # This hash defines mandatory profile values for a NFS share using the old AutoYaST style.
      #
      # Keys are the name of the section, and values are the mandatory values for such section.
      #
      # With old format, the partition section must contain a device and a mount value, e.g.:
      #
      # <drive>
      #   <device>/dev/nfs</device>
      #   <partitions>
      #     <partition>
      #       <device>192.168.56.1:/root_fs</device>
      #       <mount>/</mount>
      #     </partition>
      #   </partitions>
      # </drive>
      OLD_FORMAT_MANDATORY_VALUES = { drive: [], partition: [:device, :mount] }.freeze

      # Similar to {OLD_FORMAT_MANDATORY_VALUES}, but for the new AutoYaST style.
      #
      # TODO
      NEW_FORMAT_MANDATORY_VALUES = {}.freeze

      private_constant :OLD_FORMAT_MANDATORY_VALUES, :NEW_FORMAT_MANDATORY_VALUES

      # Returns a list of planned NFS filesystems from the old-style AutoYaST profile
      #
      # Using `/dev/nfs` as device name means that the whole drive section should be treated as an
      # old-style AutoYaST NFS description. Each partition represents an NFS filesystem and the `device`
      # is used to indicate the NFS share (e.g., `192.168.56.1:/root_fs`).
      #
      # @param drive [AutoinstProfile::DriveSection] drive section describing the list of NFS
      #   filesystems (old-style AutoYaST)
      # @return [Array<Planned::Nfs>] List of planned NFS filesystems
      def planned_devices_old_format(drive)
        drive.partitions.map { |p| planned_device_old_format(drive, p) }.compact
      end

      # Creates a planned NFS filesystem from the old-style AutoYaST profile
      #
      #
      # @param drive [AutoinstProfile::DriveSection] drive section describing the list of NFS
      #   filesystems
      # @param partition_section [AutoinstProfile::PartitionSection] partition section describing
      #   a NFS filesystem
      #
      # @return [Planned::Nfs]
      def planned_device_old_format(drive, partition_section)
        return nil unless valid_drive?(drive, partition: partition_section, profile_format: :old)

        share = partition_section.device

        planned_nfs = Planned::Nfs.new(server(share), path(share))
        add_options(planned_nfs, partition_section)

        planned_nfs
      end

      # Adds options to the planned NFS filesystem
      #
      # @param planned_nfs [Planned::Nfs]
      # @param partition_section [AutoinstProfile::PartitionSection] partition section describing
      #   a NFS filesystem
      def add_options(planned_nfs, partition_section)
        planned_nfs.mount_point = partition_section.mount
        planned_nfs.fstab_options = partition_section.fstab_options || []
      end

      # Whether the drive section is valid
      #
      # Errors are registered when the section is not valid.
      #
      # @param drive [AutoinstProfile::DriveSection]
      # @param partition [AutoinstProfile::PartitionSection]
      # @param profile_format [:new, :old] whether the section is using the new or old AutoYaST style
      #
      # @return [Boolean]
      def valid_drive?(drive, partition: nil, profile_format: :new)
        partition_section = partition || drive.partitions.first

        !missing_drive_values?(drive, profile_format) &&
          !missing_partition_values?(partition_section, profile_format)
      end

      # Whether any value is missing for the drive section
      #
      # Errors are registered when values are missing.
      #
      # @param drive [AutoinstProfile::DriveSection]
      # @param profile_format [:new, :old] whether the section is using the new or old AutoYaST style
      #
      # @return [Boolean]
      def missing_drive_values?(drive, profile_format)
        missing_any_value?(drive, mandatory_drive_values(profile_format))
      end

      # Whether any value is missing for the partition section
      #
      # Errors are registered when values are missing.
      #
      # @param partition_section [AutoinstProfile::PartitionSection]
      # @param profile_format [:new, :old] whether the section is using the new or old AutoYaST style
      #
      # @return [Boolean]
      def missing_partition_values?(partition_section, profile_format)
        missing_any_value?(partition_section, mandatory_partition_values(profile_format))
      end

      # Whether any of the given values is missing in the given section
      #
      # Note: finding the first missing value is faster, but all values are checked to
      # register all possible issues.
      #
      # @param section [AutoinstProfile::SectionWithAttributes]
      # @param values [Array<Symbol>]
      #
      # @return [Boolean]
      def missing_any_value?(section, values)
        values.map { |v| missing_value?(section, v) }.any?
      end

      # Whether the given value is missing in the given section
      #
      # An error is registered when the value is missing.
      #
      # @param section [AutoinstProfile::SectionWithAttributes]
      # @param value [Symbol]
      #
      # @return [Boolean]
      def missing_value?(section, value)
        return false if section.send(value)

        issues_list.add(:missing_value, section, value)

        true
      end

      # Mandatory values for the drive section
      #
      # @param profile_format [:new, :old] whether the section is using the new or old AutoYaST style
      # @return [Array<Symbol>]
      def mandatory_drive_values(profile_format)
        mandatory_values(profile_format)[:drive]
      end

      # Mandatory values for the partition section
      #
      # @param profile_format [:new, :old] whether the section is using the new or old AutoYaST style
      # @return [Array<Symbol>]
      def mandatory_partition_values(profile_format)
        mandatory_values(profile_format)[:partition]
      end

      # Mandatory values depending on the AutoYaST style
      #
      # @param profile_format [:new, :old] new or old AutoYaST style
      # @return [Hash<Symbol, Array<Symbol>>] see {OLD_FORMAT_MANDATORY_VALUES} and
      #   {NEW_FORMAT_MANDATORY_VALUES}
      def mandatory_values(profile_format)
        if profile_format == :new
          NEW_FORMAT_MANDATORY_VALUES
        else
          OLD_FORMAT_MANDATORY_VALUES
        end
      end

      # Name of the server from a NFS share
      #
      # @param share [String] e.g., "192.168.56.1:/root_fs"
      # @return [String] e.g., "192.168.56.1"
      def server(share)
        server_and_path(share).first || ""
      end

      # Name of the shared directory from a NFS share
      #
      # @param share [String] e.g., "192.168.56.1:/root_fs"
      # @return [String] e.g., "/root_fs"
      def path(share)
        server_and_path(share).last || ""
      end

      # Name of the server and the shared directory from a NFS share
      #
      # Note that the directory can be omitted (e.g., "192.168.56.1"). For more details,
      # see {https://tools.ietf.org/html/rfc2224}.
      #
      # @param share [String] e.g., "192.168.56.1:/root_fs"
      # @return [Array<String, nil>]
      def server_and_path(share)
        server, path = share.split(":")
        [server, path]
      end
    end
  end
end