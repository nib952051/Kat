/*
  Copyright (C) 2016 Petr Vytovtov
  Contact: Petr Vytovtov <osanwe@protonmail.ch>
  All rights reserved.

  This file is part of Kat.

  Kat is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  Kat is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with Kat.  If not, see <http://www.gnu.org/licenses/>.
*/

import QtQuick 2.0
import Sailfish.Silica 1.0

Item {
    width: maximumWidth
    height: childrenRect.height

    Column {
        width: parent.width

        Repeater {
            model: audios

            Item {
                id: audioitem
                width: maximumWidth
                height: Theme.itemSizeMedium

                IconButton {
                    id: playpausebutton
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.iconSizeMedium
                    height: Theme.iconSizeMedium
                    icon.source: "image://theme/icon-m-play"

                    onClicked: {
                        if (player.isPlaying) {
                            player.pause()
                            playpausebutton.icon.source = "image://theme/icon-m-play"
                        } else {
                            player.playMedia(audios.get(index).url)
                            playpausebutton.icon.source = "image://theme/icon-m-pause"
                            audioPlayer.open = true
                            audioPlayer.setAudios(audios, index)
                        }
                    }
                }

                Column {
                    anchors.left: playpausebutton.right
                    anchors.right: audioitem.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Theme.paddingMedium

                    Label {
                        width: parent.width
                        font.bold: true
                        truncationMode: TruncationMode.Fade
                        text: audios.get(index).title
                    }

                    Label {
                        width: parent.width
                        truncationMode: TruncationMode.Fade
                        text: audios.get(index).artist
                    }
                }
            }
        }
    }
}
