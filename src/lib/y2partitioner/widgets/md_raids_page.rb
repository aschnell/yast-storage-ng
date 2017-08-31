require "cwm/tree_pager"
require "y2partitioner/icons"
require "y2partitioner/device_graphs"
require "y2partitioner/widgets/md_raids_table"

module Y2Partitioner
  module Widgets
    # A Page for md raids: contains a {MdRaidsTable}
    class MdRaidsPage < CWM::Page
      include Yast::I18n

      # Constructor
      #
      # @param pager [CWM::TreePager]
      def initialize(pager)
        textdomain "storage"

        @pager = pager
      end

      # @macro seeAbstractWidget
      def label
        _("RAID")
      end

      # @macro seeCustomWidget
      def contents
        return @contents if @contents

        icon = Icons.small_icon(Icons::RAID)
        @contents = VBox(
          Left(
            HBox(
              Image(icon, ""),
              # TRANSLATORS: Heading
              Heading(_("RAID"))
            )
          ),
          MdRaidsTable.new(devices, @pager)
        )
      end

    private

      def devices
        Y2Storage::Md.all(DeviceGraphs.instance.current)
      end
    end
  end
end