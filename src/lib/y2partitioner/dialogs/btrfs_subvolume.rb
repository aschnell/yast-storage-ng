# encoding: utf-8

# Copyright (c) [2017-2018] SUSE LLC
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
require "cwm"
require "y2partitioner/dialogs/popup"
require "y2storage/filesystems/btrfs"

Yast.import "Popup"

module Y2Partitioner
  module Dialogs
    # Popup dialog to create a btrfs subvolume
    class BtrfsSubvolume < Popup
      include Yast::Logger

      attr_reader :filesystem
      attr_reader :form

      # @param filesystem [Y2Storage::Filesystems::BlkFilesystem] a btrfs filesystem
      def initialize(filesystem, form = nil)
        textdomain "storage"

        @filesystem = filesystem
        @form = form || Form.new
      end

      def title
        _("Add subvolume")
      end

      # Shows widgets for the subvolume attributes
      def contents
        HVSquash(
          VBox(
            Left(SubvolumePath.new(form, filesystem: filesystem)),
            Left(SubvolumeNocow.new(form, filesystem: filesystem))
          )
        )
      end

      # Custom layout
      #
      # Similar to {Popup#layout} but without help button
      def layout
        VBox(
          HSpacing(50),
          Left(Heading(Id(:title), title)),
          VStretch(),
          VSpacing(1),
          VBox(ReplacePoint(Id(:contents), Empty())),
          VSpacing(1),
          VStretch(),
          ButtonBox(
            PushButton(Id(:ok), Opt(:default), Yast::Label.OKButton),
            PushButton(Id(:cancel), Yast::Label.CancelButton)
          )
        )
      end

      # Form object for the dialog
      #
      # Widgets use this object to storage data
      class Form
        # @!attribute path
        #   subvolume path
        attr_accessor :path
        # @!attribute nocow
        #   subvolume nocow attribute
        attr_accessor :nocow

        def initialize
          @path = ""
          @nocow = false
        end
      end

      # Input field to set the subvolume path
      class SubvolumePath < CWM::InputField
        attr_reader :form
        attr_reader :filesystem

        UNSAFE_CHARS = "\n\t\v\r\s,".freeze
        private_constant :UNSAFE_CHARS

        # @param form [Dialogs::BtrfsSubvolume::Form]
        # @param filesystem [Y2Storage::Filesystems::BlkFilesystem] a btrfs filesystem
        def initialize(form, filesystem: nil)
          textdomain "storage"
          @form = form
          @filesystem = filesystem
        end

        def label
          _("Path")
        end

        def store
          form.path = value
        end

        def init
          focus
          self.value = form.path
        end

        # Validates the subvolume path
        #
        # The following conditions are checked:
        # - The subvolume path is not empty
        # - The subvolume path does not contain unsafe characters
        # - The subvolume path starts by the default subvolume path
        # - The subvolume path is unique for the filesystem
        #
        # An error popup is shown when the path contains some error.
        #
        # @return [Boolean] true if the subvolume path is valid
        def validate
          fix_path

          error = presence_error || content_error || uniqueness_error || hierarchy_error

          return true if error.nil?

          Yast::Popup.Error(error)

          focus
          false
        end

      private

        def focus
          Yast::UI.SetFocus(Id(widget_id))
        end

        # Error when the given path is empty
        #
        # @return [String, nil] nil if the path is not empty
        def presence_error
          return nil unless value.empty?

          _("Empty subvolume path not allowed.")
        end

        # Error when the given path contains unsafe characters
        #
        # @return [String, nil] nil if the path does not contain unsafe characters
        def content_error
          return nil unless /[#{UNSAFE_CHARS}]/.match?(value)

          _("Subvolume path contains unsafe characters. Be sure it\n" \
            "does not include spaces, tabs, line breaks, commas or\n" \
            "similar special characters.")
        end

        # Error when the given path already exists in the filesystem
        #
        # @return [String, nil] nil if the path does not exist yet
        def uniqueness_error
          return nil unless exist_path?

          format(_("Subvolume name %s already exists."), value)
        end

        # Error when the given path is part of an already existing path
        #
        # @return [String, nil] nil if the path is not part of an already existing path
        def hierarchy_error
          return nil if filesystem.subvolume_can_be_created?(value)

          error = format(_("Cannot create subvolume %s."), value)

          sv = filesystem.subvolume_descendants(value).first
          if sv
            error << "\n" << format(_("Delete subvolume %s first."), sv.path)
          end

          error
        end

        # Updates #value by adding the subvolumes prefix
        #
        # Path should be a relative path. Starting slashes are removed. A popup message is
        # presented when the subvolumes prefix is going to be added.
        #
        # @see Y2Storage::Filesystems::Btrfs#subvolumes_prefix
        # @see Y2Storage::Filesystems::Btrfs#btrfs_subvolume_path
        def fix_path
          log.info "Fixing BTRFS subvolume path: #{value}"

          self.value = filesystem.canonical_subvolume_name(value)
          return if value.empty?

          prefix = filesystem.subvolumes_prefix
          prefix << "/" unless prefix.empty?

          log.info "Adding BTRFS subvolumes prefix: #{prefix}"

          return value if value.start_with?(prefix)

          message = format(
            _("Only subvolume names starting with \"%{prefix}\" currently allowed!\n" \
              "Automatically prepending \"%{prefix}\" to name of subvolume."), prefix: prefix
          )
          Yast::Popup.Message(message)

          self.value = filesystem.btrfs_subvolume_path(value)
        end

        # Checks if the filesystem already has a subvolume with the entered path
        # @return [Boolean]
        def exist_path?
          filesystem.btrfs_subvolumes.any? { |s| s.path == value }
        end
      end

      # Input field to set the subvolume nocow attribute
      class SubvolumeNocow < CWM::CheckBox
        attr_reader :form
        attr_reader :filesystem

        # @param form [Dialogs::BtrfsSubvolume::Form]
        # @param filesystem [Y2Storage::Filesystems::BlkFilesystem] a btrfs filesystem
        def initialize(form, filesystem: nil)
          textdomain "storage"
          @form = form
          @filesystem = filesystem
        end

        def label
          # TRANSLATORS: noCoW is acronym to "not use Copy on Write" feature for BtrFS.
          # It is an expert value, so if no suitable expression exists in your language,
          # then keep it as it is.
          _("noCoW")
        end

        def store
          form.nocow = value
        end

        def init
          self.value = form.nocow
        end
      end
    end
  end
end
