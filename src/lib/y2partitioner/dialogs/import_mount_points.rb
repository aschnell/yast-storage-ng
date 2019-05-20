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

require "y2partitioner/dialogs/popup"
require "y2partitioner/widgets/fstab_selector"

module Y2Partitioner
  module Dialogs
    # Dialog for selecting a fstab to import mount points
    class ImportMountPoints < Popup
      # Constructor
      #
      # @param controller [Actions::Controllers::Fstabs]
      def initialize(controller)
        textdomain "storage"

        @controller = controller
      end

      def title
        _("Import Mount Points from Existing System:")
      end

      # @see #fstab_selector
      def contents
        @contents ||= MarginBox(
          1,
          0.5,
          VBox(
            fstab_selector,
            VSpacing(1),
            Left(format_widget)
          )
        )
      end

      def ok_button_label
        _("Import")
      end

    private

      # @return [Actions::Controllers::Fstabs]
      attr_reader :controller

      # Widget to select the fstab file to import mount points
      #
      # @return [Widgets::FstabSelector]
      def fstab_selector
        Widgets::FstabSelector.new(controller)
      end

      # Widget to select whether to format system volumes when importing mount points
      #
      # @return [FormatWidget]
      def format_widget
        FormatWidget.new(controller)
      end

      # This popup is slighly wider than the default popup
      def min_width
        70
      end

      # Checkbox to select whether to format system volumes
      class FormatWidget < CWM::CheckBox
        # @return [Actions::Controllers::Fstabs]
        attr_reader :controller

        # Constructor
        #
        # @param controller [Actions::Controllers::Fstabs]
        def initialize(controller)
          textdomain "storage"
          @controller = controller
        end

        def label
          _("Format System Volumes")
        end

        def init
          self.value = true

          store
        end

        def store
          controller.format_system_volumes = value
        end

        def opt
          [:notify]
        end

        # Validations are performed before the {#store} method is automatically called, see
        # {Widgets::FstabSelector#validate}.
        #
        # The controller needs to be updated with the current value of this checkbox before
        # the validations are evaluated. Otherwise, the validation cannot be correctly done.
        # For this reason, the checkbox value is stored every time that it changes its value.
        def handle
          store

          nil
        end
      end
    end
  end
end
